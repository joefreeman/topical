package topical

import "fmt"

// updateIn traverses a nested structure along path, applying callback at the leaf.
// Path elements are strings (map keys) or float64 (slice indices, from JSON).
func updateIn(value any, path []any, callback func(any) (any, error)) (any, error) {
	if len(path) == 0 {
		return callback(value)
	}
	key := path[0]
	rest := path[1:]

	switch k := key.(type) {
	case float64:
		idx := int(k)
		slice, ok := value.([]any)
		if !ok {
			return nil, fmt.Errorf("expected array, got %T", value)
		}
		if idx < 0 || idx >= len(slice) {
			return nil, fmt.Errorf("index %d out of range (len %d)", idx, len(slice))
		}
		updated, err := updateIn(slice[idx], rest, callback)
		if err != nil {
			return nil, err
		}
		result := make([]any, len(slice))
		copy(result, slice)
		result[idx] = updated
		return result, nil

	case string:
		m, ok := value.(map[string]any)
		if !ok {
			if value == nil {
				// Handle nil by creating a new map
				m = map[string]any{}
			} else {
				return nil, fmt.Errorf("expected map, got %T", value)
			}
		}
		updated, err := updateIn(m[k], rest, callback)
		if err != nil {
			return nil, err
		}
		result := make(map[string]any, len(m)+1)
		for mk, mv := range m {
			result[mk] = mv
		}
		result[k] = updated
		return result, nil

	default:
		return nil, fmt.Errorf("invalid path element type: %T", key)
	}
}

// applyUpdate applies a single update operation to a value.
// Update formats:
//
//	[0, path, value]       - set
//	[1, path, key]         - unset (delete key from map)
//	[2, path, index, vals] - insert into slice (null index = append)
//	[3, path, index, count]- delete from slice
//	[4, path, value]       - merge (shallow) into map
func applyUpdate(current any, update []any) (any, error) {
	if len(update) < 3 {
		return nil, fmt.Errorf("update too short: %v", update)
	}
	opcodeF, ok := update[0].(float64)
	if !ok {
		return nil, fmt.Errorf("invalid update opcode type: %T", update[0])
	}
	opcode := int(opcodeF)
	path, ok := toPath(update[1])
	if !ok {
		return nil, fmt.Errorf("invalid update path: %v", update[1])
	}

	switch opcode {
	case 0: // set
		val := update[2]
		return updateIn(current, path, func(_ any) (any, error) {
			return val, nil
		})

	case 1: // unset
		key, ok := update[2].(string)
		if !ok {
			return nil, fmt.Errorf("unset key must be string, got %T", update[2])
		}
		return updateIn(current, path, func(value any) (any, error) {
			m, ok := value.(map[string]any)
			if !ok {
				return nil, fmt.Errorf("expected map for unset, got %T", value)
			}
			result := make(map[string]any, len(m))
			for k, v := range m {
				if k != key {
					result[k] = v
				}
			}
			return result, nil
		})

	case 2: // insert
		if len(update) < 4 {
			return nil, fmt.Errorf("insert update too short")
		}
		values, ok := update[3].([]any)
		if !ok {
			return nil, fmt.Errorf("insert values must be array, got %T", update[3])
		}
		return updateIn(current, path, func(value any) (any, error) {
			list, ok := value.([]any)
			if !ok {
				return nil, fmt.Errorf("expected array for insert, got %T", value)
			}
			var idx int
			if update[2] == nil {
				idx = len(list)
			} else {
				f, ok := update[2].(float64)
				if !ok {
					return nil, fmt.Errorf("insert index must be number or null, got %T", update[2])
				}
				idx = int(f)
			}
			if idx < 0 || idx > len(list) {
				return nil, fmt.Errorf("insert index %d out of range (len %d)", idx, len(list))
			}
			result := make([]any, 0, len(list)+len(values))
			result = append(result, list[:idx]...)
			result = append(result, values...)
			result = append(result, list[idx:]...)
			return result, nil
		})

	case 3: // delete
		if len(update) < 4 {
			return nil, fmt.Errorf("delete update too short")
		}
		idxF, ok := update[2].(float64)
		if !ok {
			return nil, fmt.Errorf("delete index must be number, got %T", update[2])
		}
		countF, ok := update[3].(float64)
		if !ok {
			return nil, fmt.Errorf("delete count must be number, got %T", update[3])
		}
		idx := int(idxF)
		count := int(countF)
		return updateIn(current, path, func(value any) (any, error) {
			list, ok := value.([]any)
			if !ok {
				return nil, fmt.Errorf("expected array for delete, got %T", value)
			}
			if idx < 0 || idx+count > len(list) {
				return nil, fmt.Errorf("delete range [%d:%d] out of range (len %d)", idx, idx+count, len(list))
			}
			result := make([]any, 0, len(list)-count)
			result = append(result, list[:idx]...)
			result = append(result, list[idx+count:]...)
			return result, nil
		})

	case 4: // merge
		mergeVal, ok := update[2].(map[string]any)
		if !ok {
			return nil, fmt.Errorf("merge value must be map, got %T", update[2])
		}
		return updateIn(current, path, func(value any) (any, error) {
			existing, ok := value.(map[string]any)
			if !ok {
				// If existing is nil/non-map, start with empty map
				existing = map[string]any{}
			}
			result := make(map[string]any, len(existing)+len(mergeVal))
			for k, v := range existing {
				result[k] = v
			}
			for k, v := range mergeVal {
				result[k] = v
			}
			return result, nil
		})

	default:
		return nil, fmt.Errorf("unhandled update opcode: %d", opcode)
	}
}

// toPath converts a JSON-decoded path ([]any of strings and float64s) into []any.
func toPath(v any) ([]any, bool) {
	arr, ok := v.([]any)
	if !ok {
		return nil, false
	}
	return arr, true
}
