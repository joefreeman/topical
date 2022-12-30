import React from "react";

import * as models from "../models";

function svgPath(path: models.Path) {
  if (path.length > 1) {
    const [[x, y], ...rest] = path;
    return [`M ${x} ${y}`, ...rest.map(([x, y]) => `L ${x} ${y}`)].join(" ");
  } else {
    return "";
  }
}
type Props = {
  path: models.Path;
  color: string;
};

export default function Path({ path, color }: Props) {
  return (
    <svg stroke={color} strokeWidth={2} fill="none">
      <path d={svgPath(path)} />
    </svg>
  );
}
