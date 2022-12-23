import { useState, useEffect, useContext } from "react";

import { Context } from "./provider";
import Socket, { SocketState } from "./socket";

export default function useSocket(): [
  Socket | undefined,
  SocketState | undefined
] {
  const socket = useContext(Context);
  const [state, setState] = useState<SocketState>();
  useEffect(() => {
    socket?.addListener(setState);
    return () => {
      socket?.removeListener(setState);
    };
  }, [socket]);

  return [socket, state];
}
