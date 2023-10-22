import React from "react";
import { SocketProvider } from "@topical/react";

import Game from "./Game";

export default function App() {
  return (
    <SocketProvider url={`ws://${window.location.host}/socket`}>
      <div>
        <Game gameId="game1" />
      </div>
    </SocketProvider>
  );
}
