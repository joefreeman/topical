package topical

import (
	"encoding/json"
	"testing"
)

func TestEncodeNotifyWithoutParams(t *testing.T) {
	t.Parallel()
	data, err := encodeNotify("lists/abc", "add_item", []any{"hello"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	var msg []any
	json.Unmarshal(data, &msg)
	if int(msg[0].(float64)) != reqNotify {
		t.Errorf("expected opcode %d, got %v", reqNotify, msg[0])
	}
	if len(msg) != 4 {
		t.Errorf("expected 4 fields without params, got %d", len(msg))
	}
}

func TestEncodeNotifyWithParams(t *testing.T) {
	t.Parallel()
	data, err := encodeNotify("lists/abc", "add_item", []any{"hello"}, Params{"user": "joe"})
	if err != nil {
		t.Fatal(err)
	}
	var msg []any
	json.Unmarshal(data, &msg)
	if len(msg) != 5 {
		t.Errorf("expected 5 fields with params, got %d", len(msg))
	}
}

func TestEncodeExecuteWithoutParams(t *testing.T) {
	t.Parallel()
	data, err := encodeExecute(42, "lists/abc", "get_item", []any{1}, nil)
	if err != nil {
		t.Fatal(err)
	}
	var msg []any
	json.Unmarshal(data, &msg)
	if int(msg[0].(float64)) != reqExecute {
		t.Errorf("expected opcode %d, got %v", reqExecute, msg[0])
	}
	if int(msg[1].(float64)) != 42 {
		t.Errorf("expected channelID 42, got %v", msg[1])
	}
	if len(msg) != 5 {
		t.Errorf("expected 5 fields without params, got %d", len(msg))
	}
}

func TestEncodeSubscribeWithoutParams(t *testing.T) {
	t.Parallel()
	data, err := encodeSubscribe(1, "lists/abc", nil)
	if err != nil {
		t.Fatal(err)
	}
	var msg []any
	json.Unmarshal(data, &msg)
	if int(msg[0].(float64)) != reqSubscribe {
		t.Errorf("expected opcode %d, got %v", reqSubscribe, msg[0])
	}
	if len(msg) != 3 {
		t.Errorf("expected 3 fields without params, got %d", len(msg))
	}
}

func TestEncodeSubscribeWithParams(t *testing.T) {
	t.Parallel()
	data, err := encodeSubscribe(1, "lists/abc", Params{"key": "val"})
	if err != nil {
		t.Fatal(err)
	}
	var msg []any
	json.Unmarshal(data, &msg)
	if len(msg) != 4 {
		t.Errorf("expected 4 fields with params, got %d", len(msg))
	}
}

func TestEncodeUnsubscribe(t *testing.T) {
	t.Parallel()
	data, err := encodeUnsubscribe(7)
	if err != nil {
		t.Fatal(err)
	}
	var msg []any
	json.Unmarshal(data, &msg)
	if int(msg[0].(float64)) != reqUnsubscribe {
		t.Errorf("expected opcode %d, got %v", reqUnsubscribe, msg[0])
	}
	if int(msg[1].(float64)) != 7 {
		t.Errorf("expected channelID 7, got %v", msg[1])
	}
}

func TestDecodeResponse(t *testing.T) {
	t.Parallel()
	data := []byte(`[2, 1, {"items": {}}]`)
	opcode, fields, err := decodeResponse(data)
	if err != nil {
		t.Fatal(err)
	}
	if opcode != respTopicReset {
		t.Errorf("expected opcode %d, got %d", respTopicReset, opcode)
	}
	if len(fields) != 2 {
		t.Errorf("expected 2 fields, got %d", len(fields))
	}
	var channelID int
	json.Unmarshal(fields[0], &channelID)
	if channelID != 1 {
		t.Errorf("expected channelID 1, got %d", channelID)
	}
}

func TestDecodeResponseTooShort(t *testing.T) {
	t.Parallel()
	data := []byte(`[2]`)
	_, _, err := decodeResponse(data)
	if err == nil {
		t.Error("expected error for short message")
	}
}

func TestTopicKey(t *testing.T) {
	t.Parallel()
	key := topicKey("lists/abc", nil)
	if key != "lists/abc?" {
		t.Errorf("unexpected key: %s", key)
	}

	key2 := topicKey("lists/abc", Params{"b": "2", "a": "1"})
	expected := "lists/abc?a=1&b=2"
	if key2 != expected {
		t.Errorf("expected %s, got %s", expected, key2)
	}
}
