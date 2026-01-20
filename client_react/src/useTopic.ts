import { useState, useEffect, useCallback, useContext, useMemo } from "react";
import { ParamsInput } from "@topical/core";

import { Context } from "./provider";

function subscriptionReady(
  topic: (string | undefined)[],
  params: ParamsInput,
): boolean {
  return (
    topic.every((p) => typeof p !== "undefined") &&
    Object.keys(params).every((k) => typeof params[k] !== "undefined")
  );
}

// Generate a stable key for topic + params (handles undefined values)
function identityKey(topic: (string | undefined)[], params: ParamsInput): string {
  const topicPart = topic.map((p) => encodeURIComponent(p ?? "")).join("/");
  const paramsPart = Object.keys(params)
    .sort()
    .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(params[k] ?? "")}`)
    .join("&");
  return `${topicPart}?${paramsPart}`;
}

export default function useTopic<T>(
  topic: (string | undefined)[],
  params: ParamsInput = {},
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
  const [state, setState] = useState<[string, T | undefined, any]>();

  // Memoize topic and params together to avoid unnecessary re-renders
  const key = identityKey(topic, params);
  const { stableTopic, stableParams } = useMemo(
    () => ({ stableTopic: topic, stableParams: params }),
    [key],
  );

  const notify = useCallback(
    (action: string, args: any[] = []) => {
      return socket!.notify(stableTopic, action, args, stableParams);
    },
    [socket, key],
  );

  const execute = useCallback(
    (action: string, args: any[] = []) => {
      return socket!.execute(stableTopic, action, args, stableParams);
    },
    [socket, key],
  );

  useEffect(() => {
    if (subscriptionReady(stableTopic, stableParams)) {
      return socket?.subscribe<T>(
        stableTopic,
        stableParams,
        (v) => setState([key, v, undefined]),
        (e) => setState([key, undefined, e]),
      );
    }
  }, [socket, key]);

  const [stateKey, value, error] = state || [undefined, undefined, undefined];
  const loading = stateKey !== key;

  return [value, { notify, execute, error, loading }];
}
