import React from "react";
import { useSocket } from "@topical/react";

export default function SocketStatus() {
  const [_socket, state] = useSocket();
  return <p className="socketState">{state}</p>;
}
