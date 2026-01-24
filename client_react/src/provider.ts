import { Socket, type WebSocketFactory } from "@topical/core";
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
  createWebSocket?: WebSocketFactory;
  children: ReactNode;
};

export default function Provider({
  url,
  createWebSocket,
  children,
}: ProviderProps) {
  const [socket, setSocket] = useState<Socket>();
  useEffect(() => {
    const socket = new Socket(url, createWebSocket);
    setSocket(socket);
    return () => {
      socket.close();
    };
  }, [url, createWebSocket]);
  return createElement(Context.Provider, { value: socket }, children);
}
