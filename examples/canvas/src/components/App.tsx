import * as React from "react";
import { useCallback, MouseEvent, useState, useEffect } from "react";
import { SocketProvider, useTopic, useSocket } from "@topical/react";

type CursorModel = {
  position: { x: number; y: number } | null;
};

type CanvasModel = {
  cursors: Record<string, CursorModel>;
};

type CursorProps = {
  cursor: CursorModel;
};

function Cursor({ cursor }: CursorProps) {
  const position = cursor.position;
  if (position) {
    return (
      <svg
        className="cursor"
        viewBox="0 0 24 24"
        fill="none"
        style={{ left: position.x, top: position.y }}
      >
        <path
          d="M11 21L4 4L21 11L14.7353 13.6849C14.2633 13.8872 13.8872 14.2633 13.6849 14.7353L11 21Z"
          stroke="red"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="2"
        />
      </svg>
    );
  } else {
    return null;
  }
}

function useClientId() {
  const [clientId, setClientId] = useState<string>();
  useEffect(() => {
    const hash = window.location.hash.substring(1);
    if (hash) {
      setClientId(hash);
    } else {
      const id = (Math.random() * 100000).toFixed();
      window.location.href = `#${id}`;
      setClientId(id);
    }
  }, []);
  return clientId;
}

type CanvasProps = {
  clientId: string;
};

function Canvas({ clientId }: CanvasProps) {
  const [canvas, { notify }] = useTopic<CanvasModel>("canvas");
  const [drawing, setDrawing] = useState(false);
  const handleMouseMove = useCallback(
    ({ clientX, clientY }: MouseEvent<HTMLElement>) => {
      if (drawing) {
      }
      return notify("cursor_move", clientX, clientY);
    },
    [notify, drawing]
  );
  const handleMouseLeave = useCallback(() => notify("cursor_move"), [notify]);
  const handleMouseDown = useCallback(() => {
    setDrawing(true);
  }, []);
  const handleMouseUp = useCallback(() => {
    // TODO:
    setDrawing(false);
  }, []);
  if (canvas) {
    return (
      <div
        className="canvas"
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
        onMouseDown={handleMouseDown}
        onMouseUp={handleMouseUp}
      >
        <pre>{JSON.stringify(canvas)}</pre>
        {Object.keys(canvas.cursors)
          // .filter((id) => id != clientId)
          .map((id) => (
            <Cursor key={id} cursor={canvas.cursors[id]} />
          ))}
      </div>
    );
  } else {
    return <p>Loading...</p>;
  }
}

function SocketStatus() {
  const [_socket, state] = useSocket();
  return <p className="socketState">{state}</p>;
}

export default function App() {
  const clientId = useClientId();
  if (clientId) {
    return (
      <SocketProvider
        url={`ws://${window.location.host}/socket?client=${clientId}`}
      >
        <div>
          <SocketStatus />
          <Canvas clientId={clientId} />
        </div>
      </SocketProvider>
    );
  } else {
    return <p>Loading...</p>;
  }
}
