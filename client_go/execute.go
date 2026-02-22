package topical

import "context"

// Execute sends an RPC-style request and blocks until the server responds.
// The context controls the timeout.
func (c *Client) Execute(ctx context.Context, topic string, action string, args []any, params Params) (any, error) {
	c.mu.Lock()
	if c.state != Connected {
		c.mu.Unlock()
		return nil, ErrNotConnected
	}
	channelID := c.nextChannelID()
	req := &request{
		result: make(chan any, 1),
		err:    make(chan error, 1),
	}
	c.requests[channelID] = req
	c.mu.Unlock()

	if args == nil {
		args = []any{}
	}
	data, err := encodeExecute(channelID, topic, action, args, params)
	if err != nil {
		c.mu.Lock()
		delete(c.requests, channelID)
		c.mu.Unlock()
		return nil, err
	}

	if err := c.send(data); err != nil {
		c.mu.Lock()
		delete(c.requests, channelID)
		c.mu.Unlock()
		return nil, err
	}

	select {
	case result := <-req.result:
		return result, nil
	case err := <-req.err:
		return nil, err
	case <-ctx.Done():
		c.mu.Lock()
		delete(c.requests, channelID)
		c.mu.Unlock()
		return nil, ctx.Err()
	}
}

// Notify sends a fire-and-forget notification.
func (c *Client) Notify(topic string, action string, args []any, params Params) error {
	c.mu.Lock()
	if c.state != Connected {
		c.mu.Unlock()
		return ErrNotConnected
	}
	c.mu.Unlock()

	if args == nil {
		args = []any{}
	}
	data, err := encodeNotify(topic, action, args, params)
	if err != nil {
		return err
	}
	return c.send(data)
}
