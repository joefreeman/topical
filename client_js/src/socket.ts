import { applyUpdate, type Update } from "./updates";

export type SocketState = "connecting" | "connected" | "disconnected";

export type Params = Record<string, string>;

// Input type that allows undefined values (validated at runtime)
export type ParamsInput = Record<string, string | undefined>;

type Listener<T> = {
  onUpdate: (value: T) => void;
  onError?: (error: unknown) => void;
};

type Topic<T> = {
  listeners: Listener<T>[];
  topic: string[];
  params: Params;
  channelId?: number;
  value?: T;
};

type Request = {
  onSuccess: (value: unknown) => void;
  onError: (reason?: unknown) => void;
};

function validateTopic(
  parts: (string | undefined)[],
): asserts parts is string[] {
  if (parts.some((p) => typeof p === "undefined")) {
    throw new Error("topic component is undefined");
  }
}

function validateParams(params: ParamsInput): asserts params is Params {
  for (const key of Object.keys(params)) {
    if (typeof params[key] === "undefined") {
      throw new Error(`param "${key}" is undefined`);
    }
  }
}

// Generate a deterministic key for topic + params combination
function topicKey(topic: string[], params: Params): string {
  const sortedParams = Object.keys(params)
    .sort()
    .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(params[k])}`)
    .join("&");
  return `${topic.map(encodeURIComponent).join("/")}?${sortedParams}`;
}

export default class Socket {
  private socket: WebSocket;
  private closed = false;
  private state: SocketState = "disconnected";
  private lastChannelId = 0;
  private topics: Record<string, Topic<unknown>> = {};
  private requests: Record<number, Request> = {};
  private subscriptions: Record<number, string> = {};
  // Maps aliased channel IDs to their target channel IDs
  private aliases: Record<number, number> = {};
  private listeners: ((state: SocketState) => void)[] = [];

  constructor(private readonly url: string) {
    this.socket = this.open();
  }

  private open() {
    this.closed = false;
    this.setState("connecting");
    const socket = new WebSocket(this.url);
    socket.addEventListener("open", this.handleSocketOpen);
    socket.addEventListener("error", this.handleSocketError);
    socket.addEventListener("message", this.handleSocketMessage);
    socket.addEventListener("close", this.handleSocketClose);
    return socket;
  }

  getState() {
    return this.state;
  }

  isConnected() {
    return this.state === "connected";
  }

  addListener(listener: (state: SocketState) => void) {
    this.listeners.push(listener);
  }

  removeListener(listener: (state: SocketState) => void) {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  close() {
    this.closed = true;
    this.socket.close();
  }

  execute(
    topic: (string | undefined)[],
    action: string,
    args: unknown[] = [],
    params: ParamsInput = {},
  ) {
    if (!this.isConnected()) {
      return Promise.reject("not connected");
    }
    const channelId = ++this.lastChannelId;
    validateTopic(topic);
    validateParams(params);
    const message =
      Object.keys(params).length > 0
        ? [1, channelId, topic, action, args, params]
        : [1, channelId, topic, action, args];
    this.socket.send(JSON.stringify(message));
    return new Promise((resolve, reject) => {
      this.requests[channelId] = { onError: reject, onSuccess: resolve };
    });
  }

  notify(
    topic: (string | undefined)[],
    action: string,
    args: unknown[] = [],
    params: ParamsInput = {},
  ) {
    if (!this.isConnected()) {
      return;
    }
    validateTopic(topic);
    validateParams(params);
    const message =
      Object.keys(params).length > 0
        ? [0, topic, action, args, params]
        : [0, topic, action, args];
    this.socket.send(JSON.stringify(message));
  }

  subscribe<T>(
    topic: (string | undefined)[],
    onUpdate: (value: T) => void,
    onError?: (error: unknown) => void,
  ): () => void;
  subscribe<T>(
    topic: (string | undefined)[],
    params: ParamsInput,
    onUpdate: (value: T) => void,
    onError?: (error: unknown) => void,
  ): () => void;
  subscribe<T>(
    topic: (string | undefined)[],
    paramsOrOnUpdate: ParamsInput | ((value: T) => void),
    onUpdateOrOnError?: ((value: T) => void) | ((error: unknown) => void),
    onError?: (error: unknown) => void,
  ): () => void {
    let params: ParamsInput;
    let onUpdate: (value: T) => void;
    let errorHandler: ((error: unknown) => void) | undefined;

    if (typeof paramsOrOnUpdate === "function") {
      params = {};
      onUpdate = paramsOrOnUpdate;
      errorHandler = onUpdateOrOnError as
        | ((error: unknown) => void)
        | undefined;
    } else {
      params = paramsOrOnUpdate;
      onUpdate = onUpdateOrOnError as (value: T) => void;
      errorHandler = onError;
    }

    const listener = {
      onUpdate: onUpdate as (value: unknown) => void,
      onError: errorHandler,
    };
    validateTopic(topic);
    validateParams(params);
    const key = topicKey(topic, params);
    if (key in this.topics) {
      this.topics[key].listeners.push(listener);
      if ("value" in this.topics[key]) {
        onUpdate(this.topics[key].value as T);
      }
    } else {
      this.topics[key] = {
        listeners: [listener],
        topic: topic,
        params,
      };
      if (this.isConnected()) {
        this.setupSubscription(key);
      }
    }
    return () => {
      if (key in this.topics) {
        const { listeners, channelId } = this.topics[key];
        const index = listeners.indexOf(listener);
        listeners.splice(index, 1);
        if (!listeners.length) {
          if (channelId && this.isConnected()) {
            this.socket.send(JSON.stringify([3, channelId]));
            delete this.subscriptions[channelId];
          }
          delete this.topics[key];
        }
      }
    };
  }

  private setState(state: SocketState) {
    this.state = state;
    this.listeners.forEach((listener) => {
      listener(state);
    });
  }

  private setupSubscription(key: string) {
    const channelId = ++this.lastChannelId;
    const { topic, params } = this.topics[key];
    const message =
      Object.keys(params).length > 0
        ? [2, channelId, topic, params]
        : [2, channelId, topic];
    this.socket.send(JSON.stringify(message));
    this.topics[key].channelId = channelId;
    this.subscriptions[channelId] = key;
  }

  private handleSocketOpen = () => {
    this.setState("connected");
    Object.keys(this.topics).forEach((key) => {
      if (!this.topics[key].channelId) {
        this.setupSubscription(key);
      }
    });
  };

  private handleSocketError = (ev: Event) => {
    console.log("error", ev);
    // TODO: ?
  };

  private handleSocketMessage = (ev: MessageEvent) => {
    const message = JSON.parse(ev.data);
    switch (message[0]) {
      case 0:
        this.handleError(message[1], message[2]);
        break;
      case 1:
        this.handleResult(message[1], message[2]);
        break;
      case 2:
        this.handleTopicReset(message[1], message[2]);
        break;
      case 3:
        this.handleTopicUpdates(message[1], message[2]);
        break;
      case 4:
        this.handleTopicAlias(message[1], message[2]);
        break;
    }
  };

  private handleError(channelId: number, error: unknown) {
    if (channelId in this.subscriptions) {
      const key = this.subscriptions[channelId];
      this.topics[key].listeners.forEach(({ onError }) => {
        onError?.(error);
      });
      delete this.topics[key];
      delete this.subscriptions[channelId];
    } else {
      this.requests[channelId].onError(error);
      delete this.requests[channelId];
    }
  }

  private handleResult(channelId: number, result: unknown) {
    this.requests[channelId].onSuccess(result);
    delete this.requests[channelId];
  }

  private handleTopicReset(channelId: number, value: unknown) {
    const key = this.subscriptions[channelId];
    if (key) {
      this.topics[key].value = value;
      this.topics[key].listeners.forEach((l) => {
        l.onUpdate(value);
      });
    }
  }

  private handleTopicUpdates(subscriptionId: number, updates: Update[]) {
    const key = this.subscriptions[subscriptionId];
    if (key) {
      const value = updates.reduce(applyUpdate, this.topics[key].value);
      this.topics[key].value = value;
      this.topics[key].listeners.forEach((l) => {
        l.onUpdate(value);
      });
    }
  }

  private handleTopicAlias(aliasedChannelId: number, targetChannelId: number) {
    const aliasedKey = this.subscriptions[aliasedChannelId];
    const targetKey = this.subscriptions[targetChannelId];

    if (!aliasedKey || !targetKey) {
      return;
    }

    const aliasedTopic = this.topics[aliasedKey];
    const targetTopic = this.topics[targetKey];

    // Move listeners from aliased topic to target topic
    targetTopic.listeners.push(...aliasedTopic.listeners);

    // If target has a value, notify the new listeners
    if ("value" in targetTopic) {
      aliasedTopic.listeners.forEach((l) => {
        l.onUpdate(targetTopic.value);
      });
    }

    // Clean up the aliased topic
    delete this.topics[aliasedKey];
    delete this.subscriptions[aliasedChannelId];

    // Track the alias so unsubscribe works correctly
    this.aliases[aliasedChannelId] = targetChannelId;
  }

  private handleSocketClose = () => {
    this.setState("disconnected");
    this.socket.removeEventListener("open", this.handleSocketOpen);
    this.socket.removeEventListener("error", this.handleSocketError);
    this.socket.removeEventListener("message", this.handleSocketMessage);
    this.socket.removeEventListener("close", this.handleSocketClose);
    for (const key in this.topics) {
      this.topics[key].channelId = undefined;
    }
    this.subscriptions = {};
    this.aliases = {};
    for (const requestId in this.requests) {
      this.requests[requestId].onError();
    }
    this.requests = {};
    if (!this.closed) {
      // TODO: backoff (with jitter)
      setTimeout(() => {
        this.socket = this.open();
      }, 500);
    }
  };
}
