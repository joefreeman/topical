import React, { useCallback, useState } from "react";
import { useTopic } from "@topical/react";

import * as models from "../models";
import Grid from "./Grid";
import Toolbar from "./Toolbar";

function isAlive(game: models.Game | undefined, x: number, y: number) {
  return game?.alive.some((cell) => cell[0] == x && cell[1] == y);
}

type Props = {
  gameId: string;
};

export default function Game({ gameId }: Props) {
  const [zoom, setZoom] = useState(10);
  const [game, { notify }] = useTopic<models.Game>("games", gameId);
  const spawn = useCallback(
    (x: number, y: number) => notify("spawn", x, y),
    [notify]
  );
  const kill = useCallback(
    (x: number, y: number) => notify("kill", x, y),
    [notify]
  );
  const start = useCallback(() => notify("start"), [notify]);
  const stop = useCallback(() => notify("stop"), [notify]);
  const step = useCallback(() => notify("step"), [notify]);
  const load = useCallback(
    (pattern: string) => notify("load", pattern),
    [notify]
  );
  const handleCellClick = useCallback(
    (x: number, y: number) => {
      if (isAlive(game, x, y)) {
        kill(x, y);
      } else {
        spawn(x, y);
      }
    },
    [game, kill, spawn]
  );
  if (game) {
    return (
      <div>
        <Toolbar
          game={game}
          zoom={zoom}
          onStartClick={start}
          onStopClick={stop}
          onStepClick={step}
          onZoomChange={setZoom}
          onLoad={load}
        />
        <Grid game={game} zoom={zoom} onCellClick={handleCellClick} />
      </div>
    );
  } else {
    return <div>Loading...</div>;
  }
}
