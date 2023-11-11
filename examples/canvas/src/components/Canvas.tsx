import React from "react";
import { useCallback, MouseEvent, useEffect, Fragment } from "react";
import { useTopic } from "@topical/react";

import * as models from "../models";
import Cursor from "./Cursor";
import Path from "./Path";

type Props = {
  canvasId: string;
  clientId: string;
};

export default function Canvas({ canvasId, clientId }: Props) {
  const [canvas, { notify }] = useTopic<models.Canvas>(`canvases/${canvasId}`);
  const handleMouseMove = useCallback(
    ({ clientX: x, clientY: y }: MouseEvent<HTMLElement>) =>
      notify("set_position", x, y),
    [notify]
  );
  const handleMouseLeave = useCallback(() => notify("set_position"), [notify]);
  const handleMouseDown = useCallback(
    () => notify("set_drawing", true),
    [notify]
  );
  const handleMouseUp = useCallback(
    () => notify("set_drawing", false),
    [notify]
  );
  useEffect(() => {
    document.addEventListener("mouseup", handleMouseUp);
    return () => document.removeEventListener("mouseup", handleMouseUp);
  }, [handleMouseUp]);
  if (canvas) {
    return (
      <div
        className="canvas"
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
        onMouseDown={handleMouseDown}
      >
        <svg>
          {Object.keys(canvas.cursors).map((id) => {
            const cursor = canvas.cursors[id];
            return (
              <Fragment key={id}>
                {id != clientId && <Cursor cursor={cursor} />}
                {cursor.drawing && (
                  <Path path={cursor.drawing} color={cursor.color} />
                )}
              </Fragment>
            );
          })}
          {canvas.paths.map((path, index) => (
            <Path key={index} path={path.path} color={path.color} />
          ))}
        </svg>
      </div>
    );
  } else {
    return <p>Loading...</p>;
  }
}
