import type { ParamsInput } from "@topical/core";
import { useCallback, useContext, useEffect, useRef, useState } from "react";

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
function identityKey(
  topic: (string | undefined)[],
  params: ParamsInput,
): string {
  const topicPart = topic.map((p) => encodeURIComponent(p ?? "")).join("/");
  const paramsPart = Object.keys(params)
    .sort()
    .map(
      (k) => `${encodeURIComponent(k)}=${encodeURIComponent(params[k] ?? "")}`,
    )
    .join("&");
  return `${topicPart}?${paramsPart}`;
}

// Stabilize topic and params - only update references when the key changes
function useStableIdentity(
  topic: (string | undefined)[],
  params: ParamsInput,
  key: string,
): [(string | undefined)[], ParamsInput] {
  const keyRef = useRef(key);
  const stableRef = useRef({ topic, params });
  if (keyRef.current !== key) {
    keyRef.current = key;
    stableRef.current = { topic, params };
  }
  return [stableRef.current.topic, stableRef.current.params];
}

export default function useTopic<T>(
  topic: (string | undefined)[],
  params: ParamsInput = {},
): [
  T | undefined,
  {
    notify: (action: string, args?: unknown[]) => void;
    execute: (action: string, args?: unknown[]) => Promise<unknown> | undefined;
    error: unknown;
    loading: boolean;
  },
] {
  const socket = useContext(Context);
  const [state, setState] = useState<[string, T | undefined, unknown]>();

  const key = identityKey(topic, params);
  const [stableTopic, stableParams] = useStableIdentity(topic, params, key);

  const notify = useCallback(
    (action: string, args: unknown[] = []) => {
      return socket?.notify(stableTopic, action, args, stableParams);
    },
    [socket, stableTopic, stableParams],
  );

  const execute = useCallback(
    (action: string, args: unknown[] = []) => {
      return socket?.execute(stableTopic, action, args, stableParams);
    },
    [socket, stableTopic, stableParams],
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
  }, [socket, stableTopic, stableParams, key]);

  const [stateKey, value, error] = state || [undefined, undefined, undefined];
  const loading = stateKey !== key;

  return [value, { notify, execute, error, loading }];
}
