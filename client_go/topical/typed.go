package topical

import "encoding/json"

// TypedSubscription delivers typed topic values, converting from the internal
// untyped representation via a JSON round-trip.
type TypedSubscription[T any] struct {
	sub    *Subscription
	values chan T
	errors <-chan error
}

// Subscribe is a generic wrapper that converts untyped topic values to T
// via JSON marshaling/unmarshaling on each update.
func Subscribe[T any](c *Client, topic []string, params ...Params) *TypedSubscription[T] {
	sub := c.Subscribe(topic, params...)
	ts := &TypedSubscription[T]{
		sub:    sub,
		values: make(chan T, 1),
		errors: sub.Err(),
	}
	go ts.convert()
	return ts
}

func (ts *TypedSubscription[T]) convert() {
	defer close(ts.values)
	for v := range ts.sub.Values() {
		// JSON round-trip: any -> []byte -> T
		data, err := json.Marshal(v)
		if err != nil {
			continue
		}
		var typed T
		if err := json.Unmarshal(data, &typed); err != nil {
			continue
		}
		sendReplace(ts.values, typed)
	}
}

// Values returns a channel that receives the latest typed topic value on each change.
func (ts *TypedSubscription[T]) Values() <-chan T {
	return ts.values
}

// Err returns a channel that receives server-side topic errors.
func (ts *TypedSubscription[T]) Err() <-chan error {
	return ts.errors
}

// Unsubscribe removes this subscription.
func (ts *TypedSubscription[T]) Unsubscribe() {
	ts.sub.Unsubscribe()
}
