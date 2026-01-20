import { useState, useEffect, useCallback, useContext, useMemo } from "react";
import { Params } from "@topical/core";

import { Context } from "./provider";

function arrayEqual(a: any[], b: any[]) {
  return a.length == b.length && a.every((v, i) => v == b[i]);
}

function paramsEqual(a: Params, b: Params) {
  const keysA = Object.keys(a).sort();
  const keysB = Object.keys(b).sort();
  return (
    keysA.length === keysB.length &&
    keysA.every((k, i) => k === keysB[i] && a[k] === b[k])
  );
}

type TopicIdentity = {
  topic: (string | undefined)[];
  params: Params;
};

export default function useTopic<T>(
  topic: (string | undefined)[],
  params: Params = {},
): [
  T | undefined,
  {
    notify: (action: string, args?: any[]) => void;
    execute: (action: string, args?: any[]) => Promise<any>;
    error: any;
    loading: boolean;
  },
] {
  const socket = useContext(Context);
  const [state, setState] = useState<[TopicIdentity, T | undefined, any]>();

  // Memoize params to avoid unnecessary re-renders
  const stableParams = useMemo(() => params, [JSON.stringify(params)]);

  const notify = useCallback(
    (action: string, args: any[] = []) => {
      return socket!.notify(topic, action, args, stableParams);
    },
    [socket, ...topic, stableParams],
  );

  const execute = useCallback(
    (action: string, args: any[] = []) => {
      return socket!.execute(topic, action, args, stableParams);
    },
    [socket, ...topic, stableParams],
  );

  useEffect(() => {
    if (!topic.some((p) => typeof p == "undefined")) {
      return socket?.subscribe<T>(
        topic,
        stableParams,
        (v) => setState([{ topic, params: stableParams }, v, undefined]),
        (e) => setState([{ topic, params: stableParams }, undefined, e]),
      );
    }
  }, [socket, ...topic, stableParams]);

  const [stateIdentity, value, error] = state || [
    undefined,
    undefined,
    undefined,
  ];
  const loading =
    !stateIdentity ||
    !arrayEqual(topic, stateIdentity.topic) ||
    !paramsEqual(stableParams, stateIdentity.params);

  return [value, { notify, execute, error, loading }];
}
