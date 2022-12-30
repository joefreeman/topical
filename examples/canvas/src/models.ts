export type Position = {
  x: number;
  y: number;
};

export type Path = [number, number][];

export type Cursor = {
  color: string;
  position: Position | null;
  drawing?: Path;
};

export type Canvas = {
  cursors: Record<string, Cursor>;
  paths: { path: Path; color: string }[];
};
