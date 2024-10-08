import { useState, useEffect, useCallback, useContext } from "react";

import { Context } from "./provider";

function arrayEqual(a: any[], b: any[]) {
  return a.length == b.length && a.every((v, i) => v == b[i]);
}

export default function useTopic<T>(...topicParts: (string | undefined)[]): [
  T | undefined,
  {
    notify: (action: string, ...args: any[]) => void;
    execute: (action: string, ...args: any[]) => Promise<any>;
    error: any;
    loading: boolean;
  },
] {
  const socket = useContext(Context);
  const [state, setState] =
    useState<[(string | undefined)[], T | undefined, any]>();
  const notify = useCallback(
    (action: string, ...args: any[]) => {
      return socket!.notify(topicParts, action, ...args);
    },
    [socket, ...topicParts],
  );
  const execute = useCallback(
    (action: string, ...args: any[]) => {
      return socket!.execute(topicParts, action, ...args);
    },
    [socket, ...topicParts],
  );
  useEffect(() => {
    if (!topicParts.some((p) => typeof p == "undefined")) {
      return socket?.subscribe<T>(
        topicParts,
        (v) => setState([topicParts, v, undefined]),
        (e) => setState([topicParts, undefined, e]),
      );
    }
  }, [socket, ...topicParts]);
  const [stateTopic, value, error] = state || [undefined, undefined, undefined];
  const loading = !stateTopic || !arrayEqual(topicParts, stateTopic);
  return [value, { notify, execute, error, loading }];
}
