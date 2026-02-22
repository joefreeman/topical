package topical

import "encoding/json"

// Request opcodes (client -> server)
const (
	reqNotify      = 0
	reqExecute     = 1
	reqSubscribe   = 2
	reqUnsubscribe = 3
)

// Response opcodes (server -> client)
const (
	respError        = 0
	respResult       = 1
	respTopicReset   = 2
	respTopicUpdates = 3
	respTopicAlias   = 4
)

func encodeNotify(topic string, action string, args []any, params Params) ([]byte, error) {
	var msg []any
	if len(params) > 0 {
		msg = []any{reqNotify, topic, action, args, params}
	} else {
		msg = []any{reqNotify, topic, action, args}
	}
	return json.Marshal(msg)
}

func encodeExecute(channelID int, topic string, action string, args []any, params Params) ([]byte, error) {
	var msg []any
	if len(params) > 0 {
		msg = []any{reqExecute, channelID, topic, action, args, params}
	} else {
		msg = []any{reqExecute, channelID, topic, action, args}
	}
	return json.Marshal(msg)
}

func encodeSubscribe(channelID int, topic string, params Params) ([]byte, error) {
	var msg []any
	if len(params) > 0 {
		msg = []any{reqSubscribe, channelID, topic, params}
	} else {
		msg = []any{reqSubscribe, channelID, topic}
	}
	return json.Marshal(msg)
}

func encodeUnsubscribe(channelID int) ([]byte, error) {
	return json.Marshal([]any{reqUnsubscribe, channelID})
}

// decodeResponse parses a server message and returns the opcode and raw fields.
// The caller is responsible for interpreting fields based on the opcode.
func decodeResponse(data []byte) (int, []json.RawMessage, error) {
	var raw []json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return 0, nil, err
	}
	if len(raw) < 2 {
		return 0, nil, ErrInvalidMessage
	}
	var opcode int
	if err := json.Unmarshal(raw[0], &opcode); err != nil {
		return 0, nil, err
	}
	return opcode, raw[1:], nil
}
