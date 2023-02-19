import { useState, useEffect, useCallback, useContext } from "react";

import { Context } from "./provider";

export default function useTopic<T>(...topicParts: (string | undefined)[]): [
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
    (action: string, ...args: any[]) => {
      return socket!.notify(topicParts, action, ...args);
    },
    [socket, ...topicParts]
  );
  const execute = useCallback(
    (action: string, ...args: any[]) => {
      return socket!.execute(topicParts, action, ...args);
    },
    [socket, ...topicParts]
  );
  useEffect(() => {
    if (!topicParts.some((p) => typeof p == "undefined")) {
      return socket?.subscribe(topicParts, setValue, setError);
    }
  }, [socket, ...topicParts]);
  if (error) {
    throw new Error(error);
  }
  return [value, { notify, execute }];
}
