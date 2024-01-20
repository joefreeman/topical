import { applyUpdate, Update } from "./updates";

export type SocketState = "connecting" | "connected" | "disconnected";

type Listener<T> = {
  onUpdate: (value: T) => void;
  onError?: (error: any) => void;
};

type Topic<T> = {
  listeners: Listener<T>[];
  topic: string[];
  channelId?: number;
  value?: T;
};

type Request = {
  onSuccess: (value: unknown) => void;
  onError: (reason?: any) => void;
};

function validateTopic(parts: (string | undefined)[]) {
  if (parts.some((p) => typeof p == "undefined")) {
    throw new Error("topic component is undefined");
  }
}

export default class Socket {
  private socket: WebSocket;
  private closed = false;
  private state: SocketState = "disconnected";
  private lastChannelId = 0;
  private topics: Record<string, Topic<any>> = {};
  private requests: Record<number, Request> = {};
  private subscriptions: Record<number, string> = {};
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
    return this.state == "connected";
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

  execute(topic: (string | undefined)[], action: string, ...args: any[]) {
    if (!this.isConnected()) {
      return Promise.reject("not connected");
    }
    const channelId = ++this.lastChannelId;
    validateTopic(topic);
    this.socket.send(JSON.stringify([1, channelId, topic, action, args]));
    return new Promise((resolve, reject) => {
      this.requests[channelId] = { onError: reject, onSuccess: resolve };
    });
  }

  notify(topic: (string | undefined)[], action: string, ...args: any[]) {
    if (!this.isConnected()) {
      return Promise.reject("not connected");
    }
    validateTopic(topic);
    this.socket.send(JSON.stringify([0, topic, action, args]));
  }

  subscribe<T>(
    topic: (string | undefined)[],
    onUpdate: (value: T) => void,
    onError?: (error: any) => void,
  ) {
    const listener = { onUpdate, onError };
    validateTopic(topic);
    const key = topic.join("/");
    if (key in this.topics) {
      this.topics[key].listeners.push(listener);
      listener.onUpdate(this.topics[key].value);
    } else {
      this.topics[key] = { listeners: [listener], topic: topic as string[] };
      if (this.isConnected()) {
        this.setupSubscription(key);
      }
    }
    return () => {
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
    };
  }

  private setState(state: SocketState) {
    this.state = state;
    this.listeners.forEach((listener) => listener(state));
  }

  private setupSubscription(key: string) {
    const channelId = ++this.lastChannelId;
    const topic = this.topics[key].topic;
    this.socket.send(JSON.stringify([2, channelId, topic]));
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
    }
  };

  private handleError(channelId: number, error: any) {
    if (channelId in this.subscriptions) {
      const key = this.subscriptions[channelId];
      this.topics[key].listeners.forEach(
        ({ onError }) => onError && onError(error),
      );
      delete this.topics[key];
      delete this.subscriptions[channelId];
    } else {
      this.requests[channelId].onError(error);
      delete this.requests[channelId];
    }
  }

  private handleResult(channelId: number, result: any) {
    this.requests[channelId].onSuccess(result);
    delete this.requests[channelId];
  }

  private handleTopicReset(channelId: number, value: any) {
    const key = this.subscriptions[channelId];
    if (key) {
      this.topics[key].value = value;
      this.topics[key].listeners.forEach((l) => l.onUpdate(value));
    }
  }

  private handleTopicUpdates(subscriptionId: number, updates: Update[]) {
    const key = this.subscriptions[subscriptionId];
    if (key) {
      const value = updates.reduce(applyUpdate, this.topics[key].value);
      this.topics[key].value = value;
      this.topics[key].listeners.forEach((l) => l.onUpdate(value));
    }
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
