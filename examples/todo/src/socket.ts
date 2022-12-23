export type SocketState = "connecting" | "connected" | "disconnected";

type Listener<T> = {
  onUpdate: (value: T) => void;
  onError?: (error: any) => void;
};

type Topic<T> = {
  listeners: Listener<T>[];
  channelId?: number;
  value?: T;
};

type Update = [string[], any];

type Request = {
  onSuccess: (value: unknown) => void;
  onError: (reason?: any) => void;
};

function notify(listeners: ((...args: any[]) => void)[], ...args: any[]) {
  listeners.forEach((listener) => listener(...args));
}

function applyUpdate(currentValue: any, [path, newValue]: Update): any {
  if (path.length == 0) {
    return newValue;
  } else if (newValue === null && path.length == 1) {
    const [key] = path;
    const { [key]: _, ...rest } = currentValue;
    return rest;
  } else {
    const [key, ...rest] = path;
    return {
      ...currentValue,
      [key]: applyUpdate(currentValue[key], [rest, newValue]),
    };
  }
}

export default class Socket {
  private socket: WebSocket;
  private closed = false;
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
    notify(this.listeners, "connecting");
    const socket = new WebSocket(this.url);
    socket.addEventListener("open", this.handleSocketOpen);
    socket.addEventListener("error", this.handleSocketError);
    socket.addEventListener("message", this.handleSocketMessage);
    socket.addEventListener("close", this.handleSocketClose);
    return socket;
  }

  isConnected() {
    return this.socket.readyState == WebSocket.OPEN;
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

  execute(topic: string, action: string, ...args: any[]) {
    if (!this.isConnected()) {
      return Promise.reject("not connected");
    }
    const channelId = ++this.lastChannelId;
    this.socket.send(JSON.stringify([1, channelId, topic, action, args]));
    return new Promise((resolve, reject) => {
      this.requests[channelId] = { onError: reject, onSuccess: resolve };
    });
  }

  notify(topic: string, action: string, ...args: any[]) {
    if (!this.isConnected()) {
      return Promise.reject("not connected");
    }
    this.socket.send(JSON.stringify([0, topic, action, args]));
  }

  subscribe<T>(
    topic: string,
    onUpdate: (value: T) => void,
    onError?: (error: any) => void
  ) {
    const listener = { onUpdate, onError };
    if (topic in this.topics) {
      this.topics[topic].listeners.push(listener);
      listener.onUpdate(this.topics[topic].value);
    } else {
      this.topics[topic] = { listeners: [listener] };
      if (this.isConnected()) {
        this.setupSubscription(topic);
      }
    }
    return () => {
      const { listeners, channelId } = this.topics[topic];
      const index = listeners.indexOf(listener);
      listeners.splice(index, 1);
      if (!listeners.length) {
        if (channelId && this.isConnected()) {
          this.socket.send(JSON.stringify([3, channelId]));
          delete this.subscriptions[channelId];
        }
        delete this.topics[topic];
      }
    };
  }

  private setupSubscription(topic: string) {
    const channelId = ++this.lastChannelId;
    this.socket.send(JSON.stringify([2, channelId, topic]));
    this.topics[topic].channelId = channelId;
    this.subscriptions[channelId] = topic;
  }

  private handleSocketOpen = (ev: Event) => {
    notify(this.listeners, "connected");
    Object.keys(this.topics).forEach((topic) => {
      if (!this.topics[topic].channelId) {
        this.setupSubscription(topic);
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
      const topic = this.subscriptions[channelId];
      this.topics[topic].listeners.forEach(
        ({ onError }) => onError && onError(error)
      );
      delete this.topics[topic];
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
    const topic = this.subscriptions[channelId];
    this.topics[topic].value = value;
    this.topics[topic].listeners.forEach((l) => l.onUpdate(value));
  }

  private handleTopicUpdates(subscriptionId: number, updates: Update[]) {
    const topic = this.subscriptions[subscriptionId];
    const value = updates.reduce(applyUpdate, this.topics[topic].value);
    this.topics[topic].value = value;
    this.topics[topic].listeners.forEach((l) => l.onUpdate(value));
  }

  private handleSocketClose = (ev: Event) => {
    notify(this.listeners, "disconnected");
    this.socket.removeEventListener("open", this.handleSocketOpen);
    this.socket.removeEventListener("error", this.handleSocketError);
    this.socket.removeEventListener("message", this.handleSocketMessage);
    this.socket.removeEventListener("close", this.handleSocketClose);
    Object.values(this.topics).forEach((topic) => {
      topic.channelId = undefined;
    });
    this.subscriptions = {};
    Object.values(this.requests).forEach(({ onError }) => onError());
    this.requests = {};
    if (!this.closed) {
      // TODO: backoff (with jitter)
      setTimeout(() => {
        this.socket = this.open();
      }, 500);
    }
  };
}
