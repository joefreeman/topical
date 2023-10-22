import React, { useCallback } from "react";

import * as models from "../models";

type Props = {
  game: models.Game;
  zoom: number;
  onStartClick: () => void;
  onStopClick: () => void;
  onStepClick: () => void;
  onZoomChange: (zoom: number) => void;
};

export default function Toolbar({
  game,
  zoom,
  onStartClick,
  onStopClick,
  onStepClick,
  onZoomChange,
}: Props) {
  const handleZoomInClick = useCallback(
    () => onZoomChange(Math.min(20, zoom + 1)),
    [zoom, onZoomChange]
  );
  const handleZoomOutClick = useCallback(
    () => onZoomChange(Math.max(1, zoom - 1)),
    [zoom, onZoomChange]
  );
  return (
    <div>
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
