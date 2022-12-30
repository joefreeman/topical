import * as React from "react";
import { SocketProvider } from "@topical/react";

import useClientId from "../hooks/useClientId";
import SocketStatus from "./SocketStatus";
import Canvas from "./Canvas";

export default function App() {
  const clientId = useClientId();
  if (clientId) {
    return (
      <SocketProvider
        url={`ws://${window.location.host}/socket?client=${clientId}`}
      >
        <SocketStatus />
        <Canvas canvasId="foo" clientId={clientId} />
      </SocketProvider>
    );
  } else {
    return <p>Loading...</p>;
  }
}
