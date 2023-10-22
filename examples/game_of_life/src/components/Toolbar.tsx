import React, { ChangeEvent, useCallback } from "react";

import * as models from "../models";

type Props = {
  game: models.Game;
  zoom: number;
  onStartClick: () => void;
  onStopClick: () => void;
  onStepClick: () => void;
  onZoomChange: (zoom: number) => void;
  onLoad: (pattern: string) => void;
};

export default function Toolbar({
  game,
  zoom,
  onStartClick,
  onStopClick,
  onStepClick,
  onZoomChange,
  onLoad,
}: Props) {
  const handleZoomInClick = useCallback(
    () => onZoomChange(Math.min(20, zoom + 1)),
    [zoom, onZoomChange]
  );
  const handleZoomOutClick = useCallback(
    () => onZoomChange(Math.max(1, zoom - 1)),
    [zoom, onZoomChange]
  );
  const handleLoad = useCallback(
    (ev: ChangeEvent<HTMLSelectElement>) => {
      const value = ev.target.value;
      if (value) {
        onLoad(value);
      }
    },
    [onLoad]
  );
  return (
    <div>
      <select onChange={handleLoad} value="">
        <option value="">Load...</option>
        <option value="random">Random</option>
        <option value="glider_gun">Glider gun</option>
        <option value="empty">Reset</option>
      </select>{" "}
      {game.running ? (
        <button onClick={onStopClick}>Stop</button>
      ) : (
        <button onClick={onStartClick}>Start</button>
      )}
      <button onClick={onStepClick} disabled={game.running}>
        Step
      </button>{" "}
      <button onClick={handleZoomInClick}>+</button>
      <button onClick={handleZoomOutClick}>-</button>
    </div>
  );
}
