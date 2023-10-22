import React, { useCallback, useState } from "react";
import { useTopic } from "@topical/react";

import * as models from "../models";

function buildGrid(game: models.Game) {
  const alive = game.alive.reduce(
    (acc, [x, y]) => ({ ...acc, [`${x},${y}`]: true }),
    {}
  );
  const grid: boolean[][] = [];
  for (let y = 0; y < game.height; y++) {
    const row: boolean[] = [];
    for (let x = 0; x < game.width; x++) {
      row.push(!!alive[`${x},${y}`]);
    }
    grid.push(row);
  }
  return grid;
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
  const step = useCallback(() => notify("step"), [notify]);
  const start = useCallback(() => notify("start"), [notify]);
  const stop = useCallback(() => notify("stop"), [notify]);
  if (game) {
    const grid = buildGrid(game);
    return (
      <div>
        <div>
          <button onClick={step}>Step</button>
          <button onClick={() => (game.running ? stop() : start())}>
            {game.running ? "Stop" : "Start"}
          </button>{" "}
          <button onClick={() => setZoom((z) => z + 1)}>+</button>
          <button onClick={() => setZoom((z) => z - 1)}>-</button>
        </div>
        <svg
          width={game.width * zoom}
          height={game.height * zoom}
          className="board"
        >
          {grid.map((row, y) =>
            row.map((alive, x) => (
              <rect
                key={`${x},${y}`}
                x={x * zoom}
                y={y * zoom}
                width={zoom}
                height={zoom}
                className={`cell ${alive ? "alive" : "dead"}`}
                onClick={() => (alive ? kill(x, y) : spawn(x, y))}
              />
            ))
          )}
        </svg>
      </div>
    );
  } else {
    return <div>Loading...</div>;
  }
}
