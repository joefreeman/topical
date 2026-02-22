package topical

// Subscription delivers untyped topic values.
type Subscription struct {
	client   *Client
	key      string
	listener *listener
}

// Subscribe creates a subscription to the given topic. Multiple calls with the
// same topic and params share a single server subscription (reference counted).
// The topic is a slash-separated path (e.g. "lists/my-list").
func (c *Client) Subscribe(topic string, params Params) *Subscription {
	key := topicKey(topic, params)

	l := &listener{
		values: make(chan any, 1),
		errors: make(chan error, 1),
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	if t, ok := c.topics[key]; ok {
		// Existing topic - add listener
		t.listeners = append(t.listeners, l)
		if t.hasValue {
			sendReplace(l.values, t.value)
		}
	} else {
		// New topic
		t := &topicEntry{
			listeners: []*listener{l},
			topic: topic,
			params:    params,
		}
		c.topics[key] = t
		if c.state == Connected {
			c.setupSubscriptionLocked(key)
		}
	}

	return &Subscription{
		client:   c,
		key:      key,
		listener: l,
	}
}

// Values returns a channel that receives the latest topic value on each change.
func (s *Subscription) Values() <-chan any {
	return s.listener.values
}

// Err returns a channel that receives server-side topic errors.
func (s *Subscription) Err() <-chan error {
	return s.listener.errors
}

// Unsubscribe removes this subscription. When the last subscriber for a topic
// leaves, the server subscription is also cancelled.
func (s *Subscription) Unsubscribe() {
	c := s.client
	c.mu.Lock()
	defer c.mu.Unlock()

	// Already closed (e.g., by Client.Close)
	if s.listener.closed {
		return
	}

	t, ok := c.topics[s.key]
	if !ok {
		return
	}

	// Remove this listener
	for i, l := range t.listeners {
		if l == s.listener {
			t.listeners = append(t.listeners[:i], t.listeners[i+1:]...)
			break
		}
	}

	// If no more listeners, unsubscribe from server
	if len(t.listeners) == 0 {
		if t.channelID != 0 && c.state == Connected {
			data, err := encodeUnsubscribe(t.channelID)
			if err == nil {
				c.sendLocked(data)
			}
			delete(c.subscriptions, t.channelID)
		}
		delete(c.topics, s.key)
	}

	s.listener.closed = true
	close(s.listener.values)
	close(s.listener.errors)
}