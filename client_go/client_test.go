package topical

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/coder/websocket"
)

// mockServer creates a test WebSocket server that echoes back protocol messages
// according to the Topical protocol.
type mockServer struct {
	server *httptest.Server
	// handler is called for each incoming message; it returns messages to send back.
	handler func(msg []any) [][]any
}

func newMockServer(handler func(msg []any) [][]any) *mockServer {
	ms := &mockServer{handler: handler}
	ms.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()

		ctx := r.Context()
		for {
			_, data, err := conn.Read(ctx)
			if err != nil {
				return
			}
			var msg []any
			if err := json.Unmarshal(data, &msg); err != nil {
				continue
			}
			responses := ms.handler(msg)
			for _, resp := range responses {
				respData, _ := json.Marshal(resp)
				conn.Write(ctx, websocket.MessageText, respData)
			}
		}
	}))
	return ms
}

func (ms *mockServer) wsURL() string {
	return "ws" + strings.TrimPrefix(ms.server.URL, "http")
}

func (ms *mockServer) close() {
	ms.server.Close()
}

func TestConnectAndClose(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any { return nil })
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	if client.State() != Connected {
		t.Errorf("expected Connected, got %v", client.State())
	}
	client.Close()
}

func TestSubscribeReceivesReset(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqSubscribe {
			channelID := msg[1].(float64)
			// Send a topic reset with initial value
			return [][]any{
				{float64(respTopicReset), channelID, map[string]any{"items": map[string]any{}, "order": []any{}}},
			}
		}
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	sub := client.Subscribe("lists/test", nil)
	defer sub.Unsubscribe()

	select {
	case val := <-sub.Values():
		m, ok := val.(map[string]any)
		if !ok {
			t.Fatalf("expected map, got %T", val)
		}
		if _, ok := m["items"]; !ok {
			t.Error("expected 'items' key in value")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for value")
	}
}

func TestSubscribeReceivesUpdates(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqSubscribe {
			channelID := msg[1].(float64)
			return [][]any{
				// Initial reset
				{float64(respTopicReset), channelID, map[string]any{"count": float64(0)}},
				// Then an update
				{float64(respTopicUpdates), channelID, []any{
					[]any{float64(0), []any{"count"}, float64(1)},
				}},
			}
		}
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	sub := client.Subscribe("counter", nil)
	defer sub.Unsubscribe()

	// Should eventually get the updated value (count=1)
	deadline := time.After(2 * time.Second)
	for {
		select {
		case val := <-sub.Values():
			m := val.(map[string]any)
			if m["count"] == float64(1) {
				return // success
			}
		case <-deadline:
			t.Fatal("timeout waiting for updated value")
		}
	}
}

func TestExecute(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqExecute {
			channelID := msg[1].(float64)
			return [][]any{
				{float64(respResult), channelID, "hello"},
			}
		}
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	result, err := client.Execute(ctx, "lists/test", "greet", []any{"world"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if result != "hello" {
		t.Errorf("expected 'hello', got %v", result)
	}
}

func TestExecuteError(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqExecute {
			channelID := msg[1].(float64)
			return [][]any{
				{float64(respError), channelID, "not_found"},
			}
		}
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	_, err = client.Execute(ctx, "lists/test", "missing", nil, nil)
	if err == nil {
		t.Fatal("expected error")
	}
	if err.Error() != "not_found" {
		t.Errorf("expected 'not_found', got %v", err)
	}
}

func TestNotify(t *testing.T) {
	t.Parallel()
	received := make(chan []any, 1)
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqNotify {
			received <- msg
		}
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	err = client.Notify("lists/test", "ping", []any{"data"}, nil)
	if err != nil {
		t.Fatal(err)
	}

	select {
	case msg := <-received:
		action := msg[2].(string)
		if action != "ping" {
			t.Errorf("expected action 'ping', got %v", action)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for notify")
	}
}

func TestTypedSubscription(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqSubscribe {
			channelID := msg[1].(float64)
			return [][]any{
				{float64(respTopicReset), channelID, map[string]any{
					"items": map[string]any{"a": map[string]any{"text": "hello"}},
					"order": []any{"a"},
				}},
			}
		}
		return nil
	})
	defer ms.close()

	type Item struct {
		Text string `json:"text"`
	}
	type List struct {
		Items map[string]Item `json:"items"`
		Order []string        `json:"order"`
	}

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	sub := Subscribe[List](client, "lists/test", nil)
	defer sub.Unsubscribe()

	select {
	case list := <-sub.Values():
		if len(list.Items) != 1 {
			t.Errorf("expected 1 item, got %d", len(list.Items))
		}
		if list.Items["a"].Text != "hello" {
			t.Errorf("expected 'hello', got %s", list.Items["a"].Text)
		}
		if len(list.Order) != 1 || list.Order[0] != "a" {
			t.Errorf("unexpected order: %v", list.Order)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for typed value")
	}
}

func TestSubscriptionDedup(t *testing.T) {
	t.Parallel()
	var subscribeCount atomic.Int32
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqSubscribe {
			subscribeCount.Add(1)
			channelID := msg[1].(float64)
			return [][]any{
				{float64(respTopicReset), channelID, map[string]any{"count": float64(0)}},
			}
		}
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	sub1 := client.Subscribe("counter", nil)
	// Wait for first value
	select {
	case <-sub1.Values():
	case <-time.After(2 * time.Second):
		t.Fatal("timeout")
	}

	sub2 := client.Subscribe("counter", nil)
	// Second subscriber should immediately get the cached value
	select {
	case <-sub2.Values():
	case <-time.After(2 * time.Second):
		t.Fatal("timeout")
	}

	if count := subscribeCount.Load(); count != 1 {
		t.Errorf("expected 1 server subscribe, got %d", count)
	}

	sub1.Unsubscribe()
	sub2.Unsubscribe()
}

func TestTopicAlias(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqSubscribe {
			channelID := msg[1].(float64)
			topicName := msg[2].(string)
			if topicName == "first" {
				// First subscription gets a reset
				return [][]any{
					{float64(respTopicReset), channelID, map[string]any{"data": "hello"}},
				}
			}
			if topicName == "second" {
				// Second subscription is an alias to the first (channelID 1)
				return [][]any{
					{float64(respTopicAlias), channelID, float64(1)},
				}
			}
		}
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	sub1 := client.Subscribe("first", nil)
	select {
	case <-sub1.Values():
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for first value")
	}

	sub2 := client.Subscribe("second", nil)
	// Should receive the aliased value from the first topic
	select {
	case val := <-sub2.Values():
		m := val.(map[string]any)
		if m["data"] != "hello" {
			t.Errorf("expected 'hello', got %v", m["data"])
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for aliased value")
	}

	sub1.Unsubscribe()
	sub2.Unsubscribe()
}

func TestCloseUnblocksSubscribers(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any {
		opcode := int(msg[0].(float64))
		if opcode == reqSubscribe {
			channelID := msg[1].(float64)
			return [][]any{
				{float64(respTopicReset), channelID, map[string]any{"data": "initial"}},
			}
		}
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}

	sub := client.Subscribe("test", nil)
	// Drain initial value
	select {
	case <-sub.Values():
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for initial value")
	}

	// Close should cause Values() channel to be closed
	client.Close()

	select {
	case _, ok := <-sub.Values():
		if ok {
			t.Error("expected channel to be closed")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timeout: Values() channel was not closed after Client.Close()")
	}
}

func TestExecuteTimeout(t *testing.T) {
	t.Parallel()
	ms := newMockServer(func(msg []any) [][]any {
		// Never respond to execute requests
		return nil
	})
	defer ms.close()

	ctx := context.Background()
	client, err := Connect(ctx, ms.wsURL(), WithReconnect(false))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	execCtx, cancel := context.WithTimeout(ctx, 100*time.Millisecond)
	defer cancel()

	_, err = client.Execute(execCtx, "lists/test", "slow", nil, nil)
	if err == nil {
		t.Fatal("expected error from timeout")
	}
	if err != context.DeadlineExceeded {
		t.Errorf("expected DeadlineExceeded, got %v", err)
	}
}
