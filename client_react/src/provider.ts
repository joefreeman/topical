import { Socket } from "@topical/core";
import {
  createContext,
  createElement,
  type ReactNode,
  useEffect,
  useState,
} from "react";

export const Context = createContext<Socket | undefined>(undefined);

type ProviderProps = {
  url: string;
  children: ReactNode;
};

export default function Provider({ url, children }: ProviderProps) {
  const [socket, setSocket] = useState<Socket>();
  useEffect(() => {
    const socket = new Socket(url);
    setSocket(socket);
    return () => {
      socket.close();
    };
  }, [url]);
  return createElement(Context.Provider, { value: socket }, children);
}
