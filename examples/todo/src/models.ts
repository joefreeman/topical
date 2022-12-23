export type Item = {
  text: string;
  done?: boolean;
};

export type List = {
  items: Record<string, Item>;
  order: string[];
};
