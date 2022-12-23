import { useState, useEffect, useCallback } from "react";

import Socket from "./socket";

export default function useTopic<T>(
  socket: Socket | undefined,
  topic: string
): [
  T | undefined,
  {
    notify: (action: string, ...args: any[]) => void;
    execute: (action: string, ...args: any[]) => Promise<any>;
  }
] {
  const [value, setValue] = useState<T>();
  const [error, setError] = useState<any>();
  const notify = useCallback(
    (action: string, ...args: any[]) => socket!.notify(topic, action, ...args),
    [socket, topic]
  );
  const execute = useCallback(
    (action: string, ...args: any[]) => socket!.execute(topic, action, ...args),
    [socket, topic]
  );
  useEffect(() => {
    return socket?.subscribe(topic, setValue, setError);
  }, [socket, topic]);
  if (error) {
    throw new Error(error);
  }
  return [value, { notify, execute }];
}
