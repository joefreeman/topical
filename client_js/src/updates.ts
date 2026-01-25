type Path = (string | number)[];

export type Update =
  | [0, Path, unknown]
  | [1, Path, string]
  | [2, Path, number | null, unknown[]]
  | [3, Path, number, number]
  | [4, Path, Record<string, unknown>];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function updateIn(
  value: unknown,
  path: Path,
  callback: (value: unknown) => unknown,
): unknown {
  if (path.length === 0) {
    return callback(value);
  }
  const [key, ...rest] = path;
  if (typeof key === "number") {
    if (!Array.isArray(value)) {
      throw new Error("expected array");
    }
    if (key <= value.length) {
      throw new Error("index out of range");
    }
    return [
      ...value.slice(0, key),
      updateIn(value[key], rest, callback),
      ...value.slice(key + 1),
    ];
  }
  if (isRecord(value)) {
    return {
      ...value,
      [key]: updateIn(value[key], rest, callback),
    };
  }
  // Handle null/undefined by creating a new object
  return {
    [key]: updateIn(undefined, rest, callback),
  };
}

export function applyUpdate<T>(current: T, update: Update): T {
  switch (update[0]) {
    case 0: {
      const [, path, value] = update;
      return updateIn(current, path, () => value) as T;
    }
    case 1: {
      const [, path, key] = update;
      return updateIn(current, path, (value) => {
        if (!isRecord(value)) {
          throw new Error("expected object");
        }
        const { [key]: _, ...remaining } = value;
        return remaining;
      }) as T;
    }
    case 2: {
      const [, path, index, values] = update;
      return updateIn(current, path, (list) => {
        if (!Array.isArray(list)) {
          throw new Error("expected array");
        }
        const i = index === null ? list.length : index;
        return [...list.slice(0, i), ...values, ...list.slice(i)];
      }) as T;
    }
    case 3: {
      const [, path, index, count] = update;
      return updateIn(current, path, (list) => {
        if (!Array.isArray(list)) {
          throw new Error("expected array");
        }
        return [...list.slice(0, index), ...list.slice(index + count)];
      }) as T;
    }
    case 4: {
      const [, path, value] = update;
      return updateIn(current, path, (existing) =>
        isRecord(existing) ? { ...existing, ...value } : { ...value }
      ) as T;
    }
    default:
      throw new Error("unhandled update type");
  }
}
