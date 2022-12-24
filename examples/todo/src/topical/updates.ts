type Path = (string | number)[];

export type Update =
  | [0, Path, any]
  | [1, Path, string]
  | [2, Path, number, any[]]
  | [3, Path, number, number];

function updateIn(value: any, path: Path, callback: (value: any) => any) {
  if (path.length == 0) {
    return callback(value);
  } else {
    const [key, ...rest] = path;
    if (typeof key == "number") {
      if (!Array.isArray(value)) {
        throw new Error("expected array");
      }
      if (key <= value.length) {
        throw new Error("index out of range");
      }
      return [
        ...value.slice(0, key),
        updateIn(value[key], rest, callback),
        ...value.slice(key + 1),
      ];
    } else {
      return {
        ...value,
        [key]: updateIn(value[key], rest, callback),
      };
    }
  }
}

export function applyUpdate(current: any, update: Update): any {
  const [operation, path, ...rest] = update;
  switch (operation) {
    case 0: {
      const [value] = rest;
      return updateIn(current, path, () => value);
    }
    case 1: {
      const [key] = rest;
      return updateIn(current, path, ({ [key]: _, ...rest }) => rest);
    }
    case 2: {
      const [index, values] = rest;
      return updateIn(current, path, (list) => [
        ...list.slice(0, index),
        ...(values as any[]),
        ...list.slice(index),
      ]);
    }
    case 3: {
      const [index, count] = rest;
      return updateIn(current, path, (list) => [
        ...list.slice(0, index),
        ...list.slice(index + count),
      ]);
    }
    default:
      throw new Error("unhandled update type");
  }
}
