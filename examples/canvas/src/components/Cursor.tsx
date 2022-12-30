import React from "react";

import * as models from "../models";

type Props = {
  cursor: models.Cursor;
};

export default function Cursor({ cursor }: Props) {
  const position = cursor.position;
  if (position) {
    return (
      <svg
        className="cursor"
        x={position.x}
        y={position.y}
        stroke={cursor.color}
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        fill="none"
      >
        <path d="M11 21L4 4L21 11L14.7353 13.6849C14.2633 13.8872 13.8872 14.2633 13.6849 14.7353L11 21Z" />
      </svg>
    );
  } else {
    return null;
  }
}
