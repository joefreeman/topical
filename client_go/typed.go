package topical

import (
	"encoding/json"
	"fmt"
)

// TypedSubscription delivers typed topic values, converting from the internal
// untyped representation via a JSON round-trip.
type TypedSubscription[T any] struct {
	sub    *Subscription
	values chan T
	errors chan error
}

// Subscribe is a generic wrapper that converts untyped topic values to T
// via JSON marshaling/unmarshaling on each update.
func Subscribe[T any](c *Client, topic string, params Params) *TypedSubscription[T] {
	sub := c.Subscribe(topic, params)
	ts := &TypedSubscription[T]{
		sub:    sub,
		values: make(chan T, 1),
		errors: make(chan error, 1),
	}
	go ts.convert()
	return ts
}

func (ts *TypedSubscription[T]) convert() {
	defer close(ts.values)
	defer close(ts.errors)
	for {
		select {
		case v, ok := <-ts.sub.Values():
			if !ok {
				return
			}
			data, err := json.Marshal(v)
			if err != nil {
				sendNonBlocking(ts.errors, fmt.Errorf("topical: marshal: %w", err))
				continue
			}
			var typed T
			if err := json.Unmarshal(data, &typed); err != nil {
				sendNonBlocking(ts.errors, fmt.Errorf("topical: unmarshal: %w", err))
				continue
			}
			sendReplace(ts.values, typed)
		case err, ok := <-ts.sub.Err():
			if !ok {
				return
			}
			sendNonBlocking(ts.errors, err)
		}
	}
}

// Values returns a channel that receives the latest typed topic value on each change.
func (ts *TypedSubscription[T]) Values() <-chan T {
	return ts.values
}

// Err returns a channel that receives subscription and conversion errors.
func (ts *TypedSubscription[T]) Err() <-chan error {
	return ts.errors
}

// Unsubscribe removes this subscription.
func (ts *TypedSubscription[T]) Unsubscribe() {
	ts.sub.Unsubscribe()
}
