package topical

import (
	"encoding/json"
	"testing"
)

// helper: parse JSON string into any (mimics what we get from the wire)
func j(s string) any {
	var v any
	if err := json.Unmarshal([]byte(s), &v); err != nil {
		panic(err)
	}
	return v
}

func TestSetRootValue(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": 1}`)
	update := j(`[0, [], 2]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `2`)
}

func TestSetNewValue(t *testing.T) {
	t.Parallel()
	current := j(`{}`)
	update := j(`[0, ["foo", "bar"], 2]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": {"bar": 2}}`)
}

func TestSetValueWithinList(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": [0, {"bar": 1}, 2]}`)
	update := j(`[0, ["foo", 1, "bar"], 3]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": [0, {"bar": 3}, 2]}`)
}

func TestReplaceExistingValue(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": {"bar": 1, "baz": 2}}`)
	update := j(`[0, ["foo", "bar"], 3]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": {"bar": 3, "baz": 2}}`)
}

func TestUnsetValue(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": {"bar": 2}}`)
	update := j(`[1, ["foo"], "bar"]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": {}}`)
}

func TestUnsetValueWithinList(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": [0, {"bar": 1}, 2]}`)
	update := j(`[1, ["foo", 1], "bar"]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": [0, {}, 2]}`)
}

func TestResetValue(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": {"bar": 2}}`)
	update := j(`[0, [], null]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	if result != nil {
		t.Fatalf("expected nil, got %v", result)
	}
}

func TestInsertIntoList(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": [0, 1, 2]}`)
	update := j(`[2, ["foo"], 1, [3, 4]]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": [0, 3, 4, 1, 2]}`)
}

func TestDeleteFromList(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": [0, 1, 2, 3]}`)
	update := j(`[3, ["foo"], 1, 2]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": [0, 3]}`)
}

func TestMergeValue(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": {"bar": {"a": 1, "b": 2}}}`)
	update := j(`[4, ["foo", "bar"], {"b": 3, "c": 4}]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": {"bar": {"a": 1, "b": 3, "c": 4}}}`)
}

func TestMergeNonExistingValue(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": {}}`)
	update := j(`[4, ["foo", "bar"], {"a": 1}]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": {"bar": {"a": 1}}}`)
}

func TestInsertAppend(t *testing.T) {
	t.Parallel()
	current := j(`{"foo": [0, 1]}`)
	update := j(`[2, ["foo"], null, [2, 3]]`).([]any)
	result, err := applyUpdate(current, update)
	if err != nil {
		t.Fatal(err)
	}
	assertJSON(t, result, `{"foo": [0, 1, 2, 3]}`)
}

// assertJSON checks that the JSON representation of got matches the expected JSON string.
func assertJSON(t *testing.T, got any, expectedJSON string) {
	t.Helper()
	gotBytes, err := json.Marshal(got)
	if err != nil {
		t.Fatalf("failed to marshal result: %v", err)
	}
	// Normalize both by unmarshaling and remarshaling
	var gotNorm, expNorm any
	if err := json.Unmarshal(gotBytes, &gotNorm); err != nil {
		t.Fatalf("failed to unmarshal result: %v", err)
	}
	if err := json.Unmarshal([]byte(expectedJSON), &expNorm); err != nil {
		t.Fatalf("failed to unmarshal expected: %v", err)
	}
	gotNormBytes, _ := json.Marshal(gotNorm)
	expNormBytes, _ := json.Marshal(expNorm)
	if string(gotNormBytes) != string(expNormBytes) {
		t.Errorf("mismatch:\n  got:      %s\n  expected: %s", gotNormBytes, expNormBytes)
	}
}
