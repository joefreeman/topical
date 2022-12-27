import { useState, useEffect, useCallback, useContext } from "react";

import { Context } from "./provider";

export default function useTopic<T>(topic: string): [
  T | undefined,
  {
    notify: (action: string, ...args: any[]) => void;
    execute: (action: string, ...args: any[]) => Promise<any>;
  }
] {
  const socket = useContext(Context);
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
