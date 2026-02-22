package topical

import (
	"context"
	"encoding/json"
	"errors"
	"math/rand/v2"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/coder/websocket"
)

// State represents the connection state.
type State int

const (
	Connecting   State = iota
	Connected
	Disconnected
)

func (s State) String() string {
	switch s {
	case Connecting:
		return "connecting"
	case Connected:
		return "connected"
	case Disconnected:
		return "disconnected"
	default:
		return "unknown"
	}
}

// Params holds topic parameters.
type Params map[string]string

var (
	// ErrNotConnected is returned when an operation requires a connection but the client is not connected.
	ErrNotConnected = errors.New("topical: not connected")
	// ErrInvalidMessage is returned when a received message cannot be decoded.
	ErrInvalidMessage = errors.New("topical: invalid message")
)

type clientConfig struct {
	reconnect   bool
	backoffBase time.Duration
	backoffMax  time.Duration
	dialOptions *websocket.DialOptions
}

// Option configures a Client.
type Option func(*clientConfig)

// WithReconnect enables or disables automatic reconnection.
func WithReconnect(enabled bool) Option {
	return func(c *clientConfig) { c.reconnect = enabled }
}

// WithBackoff configures reconnection backoff timing.
func WithBackoff(base, max time.Duration) Option {
	return func(c *clientConfig) {
		c.backoffBase = base
		c.backoffMax = max
	}
}

// WithDialOptions sets WebSocket dial options.
func WithDialOptions(opts *websocket.DialOptions) Option {
	return func(c *clientConfig) { c.dialOptions = opts }
}

type request struct {
	result chan any
	err    chan error
}

type topicEntry struct {
	listeners []*listener
	topic     string
	params    Params
	channelID int
	value     any
	hasValue  bool
}

type listener struct {
	values chan any
	errors chan error
	closed bool
}

// Client manages a WebSocket connection to a Topical server.
type Client struct {
	mu             sync.Mutex
	url            string
	config         clientConfig
	conn           *websocket.Conn
	state          State
	closed         bool
	lastChannelID  int
	topics         map[string]*topicEntry
	requests       map[int]*request
	subscriptions  map[int]string // channelID -> topic key
	aliases        map[int]int    // aliased channelID -> target channelID
	stateListeners map[int]chan State
	nextListenerID int
	ctx            context.Context
	cancel         context.CancelFunc
	wg             sync.WaitGroup
}

// Connect establishes a WebSocket connection to the given URL.
func Connect(ctx context.Context, rawURL string, opts ...Option) (*Client, error) {
	cfg := clientConfig{
		reconnect:   true,
		backoffBase: 500 * time.Millisecond,
		backoffMax:  30 * time.Second,
	}
	for _, o := range opts {
		o(&cfg)
	}

	clientCtx, cancel := context.WithCancel(context.Background())

	c := &Client{
		url:            rawURL,
		config:         cfg,
		state:          Connecting,
		topics:         make(map[string]*topicEntry),
		requests:       make(map[int]*request),
		subscriptions:  make(map[int]string),
		aliases:        make(map[int]int),
		stateListeners: make(map[int]chan State),
		ctx:            clientCtx,
		cancel:         cancel,
	}

	conn, _, err := websocket.Dial(ctx, rawURL, cfg.dialOptions)
	if err != nil {
		cancel()
		return nil, err
	}
	conn.SetReadLimit(-1)
	c.conn = conn
	c.state = Connected

	// Resubscribe existing topics (none on first connect, but used after reconnect)
	c.mu.Lock()
	for key := range c.topics {
		c.setupSubscriptionLocked(key)
	}
	c.mu.Unlock()

	c.wg.Add(1)
	go c.readLoop()

	return c, nil
}

// Close shuts down the client and its WebSocket connection.
func (c *Client) Close() error {
	c.mu.Lock()
	if c.closed {
		c.mu.Unlock()
		return nil
	}
	c.closed = true
	c.mu.Unlock()

	c.cancel()
	if c.conn != nil {
		c.conn.Close(websocket.StatusNormalClosure, "")
	}
	c.wg.Wait()
	return nil
}

// State returns the current connection state.
func (c *Client) State() State {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.state
}

// StateSubscription receives connection state changes.
type StateSubscription struct {
	client *Client
	id     int
	ch     chan State
}

// C returns a channel that receives state changes.
func (ss *StateSubscription) C() <-chan State {
	return ss.ch
}

// Close removes this state subscription.
func (ss *StateSubscription) Close() {
	ss.client.mu.Lock()
	defer ss.client.mu.Unlock()
	delete(ss.client.stateListeners, ss.id)
}

// StateChanges returns a subscription that receives connection state changes.
func (c *Client) StateChanges() *StateSubscription {
	c.mu.Lock()
	id := c.nextListenerID
	c.nextListenerID++
	ch := make(chan State, 1)
	c.stateListeners[id] = ch
	c.mu.Unlock()
	return &StateSubscription{client: c, id: id, ch: ch}
}

// notifyStateListeners sends the new state to all state listener channels.
func (c *Client) notifyStateListeners(s State) {
	c.mu.Lock()
	listeners := make([]chan State, 0, len(c.stateListeners))
	for _, ch := range c.stateListeners {
		listeners = append(listeners, ch)
	}
	c.mu.Unlock()
	for _, ch := range listeners {
		sendReplace(ch, s)
	}
}

func (c *Client) nextChannelID() int {
	c.lastChannelID++
	return c.lastChannelID
}

func (c *Client) readLoop() {
	defer c.wg.Done()
	for {
		_, data, err := c.conn.Read(c.ctx)
		if err != nil {
			c.handleDisconnect()
			return
		}
		c.handleMessage(data)
	}
}

func (c *Client) handleMessage(data []byte) {
	opcode, fields, err := decodeResponse(data)
	if err != nil {
		return
	}

	switch opcode {
	case respError:
		c.handleError(fields)
	case respResult:
		c.handleResult(fields)
	case respTopicReset:
		c.handleTopicReset(fields)
	case respTopicUpdates:
		c.handleTopicUpdates(fields)
	case respTopicAlias:
		c.handleTopicAlias(fields)
	}
}

func (c *Client) handleError(fields []json.RawMessage) {
	if len(fields) < 2 {
		return
	}
	var channelID int
	if err := json.Unmarshal(fields[0], &channelID); err != nil {
		return
	}
	var errorVal any
	json.Unmarshal(fields[1], &errorVal)

	c.mu.Lock()
	defer c.mu.Unlock()

	if key, ok := c.subscriptions[channelID]; ok {
		if t, ok := c.topics[key]; ok {
			for _, l := range t.listeners {
				sendNonBlocking(l.errors, errors.New(errorString(errorVal)))
			}
			delete(c.topics, key)
		}
		delete(c.subscriptions, channelID)
	} else if req, ok := c.requests[channelID]; ok {
		sendNonBlocking(req.err, errors.New(errorString(errorVal)))
		delete(c.requests, channelID)
	}
}

func (c *Client) handleResult(fields []json.RawMessage) {
	if len(fields) < 2 {
		return
	}
	var channelID int
	if err := json.Unmarshal(fields[0], &channelID); err != nil {
		return
	}
	var result any
	json.Unmarshal(fields[1], &result)

	c.mu.Lock()
	req, ok := c.requests[channelID]
	if ok {
		delete(c.requests, channelID)
	}
	c.mu.Unlock()

	if ok {
		sendNonBlocking(req.result, result)
	}
}

func (c *Client) handleTopicReset(fields []json.RawMessage) {
	if len(fields) < 2 {
		return
	}
	var channelID int
	if err := json.Unmarshal(fields[0], &channelID); err != nil {
		return
	}
	var value any
	json.Unmarshal(fields[1], &value)

	c.mu.Lock()
	key, ok := c.subscriptions[channelID]
	if !ok {
		c.mu.Unlock()
		return
	}
	t, ok := c.topics[key]
	if !ok {
		c.mu.Unlock()
		return
	}
	t.value = value
	t.hasValue = true
	listeners := make([]*listener, len(t.listeners))
	copy(listeners, t.listeners)
	c.mu.Unlock()

	for _, l := range listeners {
		sendReplace(l.values, value)
	}
}

func (c *Client) handleTopicUpdates(fields []json.RawMessage) {
	if len(fields) < 2 {
		return
	}
	var channelID int
	if err := json.Unmarshal(fields[0], &channelID); err != nil {
		return
	}
	var updates [][]any
	if err := json.Unmarshal(fields[1], &updates); err != nil {
		return
	}

	c.mu.Lock()
	key, ok := c.subscriptions[channelID]
	if !ok {
		c.mu.Unlock()
		return
	}
	t, ok := c.topics[key]
	if !ok {
		c.mu.Unlock()
		return
	}

	value := t.value
	for _, u := range updates {
		var err error
		value, err = applyUpdate(value, u)
		if err != nil {
			c.mu.Unlock()
			return
		}
	}
	t.value = value
	t.hasValue = true
	listeners := make([]*listener, len(t.listeners))
	copy(listeners, t.listeners)
	c.mu.Unlock()

	for _, l := range listeners {
		sendReplace(l.values, value)
	}
}

func (c *Client) handleTopicAlias(fields []json.RawMessage) {
	if len(fields) < 2 {
		return
	}
	var aliasedChannelID, targetChannelID int
	if err := json.Unmarshal(fields[0], &aliasedChannelID); err != nil {
		return
	}
	if err := json.Unmarshal(fields[1], &targetChannelID); err != nil {
		return
	}

	c.mu.Lock()
	aliasedKey, ok1 := c.subscriptions[aliasedChannelID]
	targetKey, ok2 := c.subscriptions[targetChannelID]
	if !ok1 || !ok2 {
		c.mu.Unlock()
		return
	}
	aliasedTopic := c.topics[aliasedKey]
	targetTopic := c.topics[targetKey]
	if aliasedTopic == nil || targetTopic == nil {
		c.mu.Unlock()
		return
	}

	// Move listeners from aliased to target
	movedListeners := make([]*listener, len(aliasedTopic.listeners))
	copy(movedListeners, aliasedTopic.listeners)
	targetTopic.listeners = append(targetTopic.listeners, movedListeners...)

	hasValue := targetTopic.hasValue
	value := targetTopic.value

	// Clean up aliased topic
	delete(c.topics, aliasedKey)
	delete(c.subscriptions, aliasedChannelID)
	c.aliases[aliasedChannelID] = targetChannelID
	c.mu.Unlock()

	// Notify moved listeners of current value
	if hasValue {
		for _, l := range movedListeners {
			sendReplace(l.values, value)
		}
	}
}

func (c *Client) handleDisconnect() {
	c.mu.Lock()
	c.state = Disconnected

	// Clear channel IDs from topics (they'll be reassigned on reconnect)
	for _, t := range c.topics {
		t.channelID = 0
	}
	c.subscriptions = make(map[int]string)
	c.aliases = make(map[int]int)

	// Reject pending requests
	for _, req := range c.requests {
		sendNonBlocking(req.err, ErrNotConnected)
	}
	c.requests = make(map[int]*request)

	shouldReconnect := c.config.reconnect && !c.closed

	// If closed and not reconnecting, close all listener channels so consumers unblock
	if c.closed {
		for _, t := range c.topics {
			for _, l := range t.listeners {
				if !l.closed {
					l.closed = true
					close(l.values)
					close(l.errors)
				}
			}
		}
		for _, ch := range c.stateListeners {
			close(ch)
		}
	}

	c.mu.Unlock()

	c.notifyStateListeners(Disconnected)

	if shouldReconnect {
		c.reconnect()
	}
}

func (c *Client) reconnect() {
	delay := c.config.backoffBase
	for {
		select {
		case <-c.ctx.Done():
			return
		case <-time.After(jitter(delay)):
		}

		c.mu.Lock()
		if c.closed {
			c.mu.Unlock()
			return
		}
		c.state = Connecting
		c.mu.Unlock()

		c.notifyStateListeners(Connecting)

		conn, _, err := websocket.Dial(c.ctx, c.url, c.config.dialOptions)
		if err != nil {
			delay = min(delay*2, c.config.backoffMax)
			c.mu.Lock()
			c.state = Disconnected
			c.mu.Unlock()
			c.notifyStateListeners(Disconnected)
			continue
		}
		conn.SetReadLimit(-1)

		c.mu.Lock()
		c.conn = conn
		c.state = Connected

		// Resubscribe all active topics
		for key := range c.topics {
			c.setupSubscriptionLocked(key)
		}
		c.mu.Unlock()

		c.notifyStateListeners(Connected)

		c.wg.Add(1)
		go c.readLoop()
		return
	}
}

func (c *Client) setupSubscriptionLocked(key string) {
	t := c.topics[key]
	if t == nil {
		return
	}
	channelID := c.nextChannelID()
	t.channelID = channelID
	c.subscriptions[channelID] = key

	data, err := encodeSubscribe(channelID, t.topic, t.params)
	if err != nil {
		return
	}
	c.conn.Write(c.ctx, websocket.MessageText, data)
}

func (c *Client) send(data []byte) error {
	c.mu.Lock()
	conn := c.conn
	ctx := c.ctx
	c.mu.Unlock()
	if conn == nil {
		return ErrNotConnected
	}
	return conn.Write(ctx, websocket.MessageText, data)
}

// sendLocked writes data on the current connection. Must be called with c.mu held.
func (c *Client) sendLocked(data []byte) error {
	if c.conn == nil {
		return ErrNotConnected
	}
	return c.conn.Write(c.ctx, websocket.MessageText, data)
}

// topicKey generates a deterministic key for a topic + params combination.
func topicKey(topic string, params Params) string {
	var b strings.Builder
	b.WriteString(topic)
	b.WriteByte('?')
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for i, k := range keys {
		if i > 0 {
			b.WriteByte('&')
		}
		b.WriteString(url.QueryEscape(k))
		b.WriteByte('=')
		b.WriteString(url.QueryEscape(params[k]))
	}
	return b.String()
}

// sendReplace sends a value on a buffered channel (size 1), draining the old value if needed.
// This function assumes a single goroutine sends to ch at a time (the readLoop goroutine).
// Multiple concurrent senders would race on the drain-then-send sequence.
func sendReplace[T any](ch chan T, val T) {
	select {
	case ch <- val:
	default:
		// Drain stale value and send new one
		select {
		case <-ch:
		default:
		}
		select {
		case ch <- val:
		default:
		}
	}
}

// sendNonBlocking tries to send on a buffered channel without blocking.
func sendNonBlocking[T any](ch chan T, val T) {
	select {
	case ch <- val:
	default:
	}
}

func errorString(v any) string {
	switch e := v.(type) {
	case string:
		return e
	case map[string]any:
		if msg, ok := e["message"]; ok {
			return errorString(msg)
		}
		b, _ := json.Marshal(e)
		return string(b)
	default:
		b, _ := json.Marshal(v)
		return string(b)
	}
}

func jitter(d time.Duration) time.Duration {
	// +/-25% jitter
	factor := 0.75 + rand.Float64()*0.5
	return time.Duration(float64(d) * factor)
}
