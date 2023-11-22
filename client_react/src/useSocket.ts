import { useState, useEffect, useContext } from "react";
import { Socket, SocketState } from "@topical/core";

import { Context } from "./provider";

export default function useSocket(): [
  Socket | undefined,
  SocketState | undefined
] {
  const socket = useContext(Context);
  const [state, setState] = useState<SocketState>();
  useEffect(() => {
    if (socket) {
      setState(socket.getState());
      socket.addListener(setState);
      return () => {
        socket.removeListener(setState);
      };
    }
  }, [socket]);

  return [socket, state];
}
