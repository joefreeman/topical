import React from "react";

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
  game: models.Game;
  zoom: number;
  onCellClick: (x: number, y: number) => void;
};

export default function Grid({ game, zoom, onCellClick }: Props) {
  const grid = buildGrid(game);
  return (
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
            onClick={() => onCellClick(x, y)}
          />
        ))
      )}
    </svg>
  );
}
