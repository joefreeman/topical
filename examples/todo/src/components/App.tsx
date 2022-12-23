import * as React from "react";
import {
  ChangeEvent,
  FormEvent,
  Fragment,
  useCallback,
  useEffect,
  useState,
} from "react";

import * as models from "../models";
import Socket, { SocketState } from "../socket";
import useTopic from "../useTopic";

function useSocket() {
  const [socket, setSocket] = useState<Socket>();
  const [state, setState] = useState<SocketState>();
  useEffect(() => {
    const socket = new Socket(`ws://${window.location.host}/socket`);
    socket.addListener(setState);
    setSocket(socket);
    return () => {
      socket.removeListener(setState);
      socket.close();
    };
  }, []);
  return [socket, state] as const;
}

type ItemProps = {
  item: models.Item;
  itemId: string;
  onDoneChange: (id: string, done: boolean) => void;
};

function Item({ item, itemId, onDoneChange }: ItemProps) {
  const handleDoneChange = useCallback(
    (ev: ChangeEvent<HTMLInputElement>) => {
      onDoneChange(itemId, ev.target.checked);
    },
    [itemId, onDoneChange]
  );
  return (
    <Fragment>
      <input
        type="checkbox"
        checked={item.done || false}
        onChange={handleDoneChange}
      />
      {item.text}
    </Fragment>
  );
}

type ListProps = {
  list: models.List;
  onDoneChange: (id: string, done: boolean) => void;
};

function List({ list, onDoneChange }: ListProps) {
  return (
    <ol>
      {list.order.map((id: string) => (
        <li key={id}>
          <Item item={list.items[id]} itemId={id} onDoneChange={onDoneChange} />
        </li>
      ))}
    </ol>
  );
}

type FormProps = {
  onSubmit: (text: string) => Promise<unknown>;
};

function Form({ onSubmit }: FormProps) {
  const [text, setText] = useState("");
  const handleChange = useCallback(
    (ev: ChangeEvent<HTMLInputElement>) => setText(ev.target.value),
    []
  );
  const handleSubmit = useCallback(
    (ev: FormEvent<HTMLFormElement>) => {
      ev.preventDefault();
      onSubmit(text).then(() => {
        setText("");
      });
    },
    [text]
  );
  return (
    <form onSubmit={handleSubmit}>
      <input type="text" value={text} onChange={handleChange} />
    </form>
  );
}

export default function App() {
  const [socket, state] = useSocket();
  const topic = "lists/foo";
  const [list, { execute, notify }] = useTopic<models.List>(socket, topic);
  const handleSubmit = useCallback(
    (text: string) => execute("add_item", text),
    [socket]
  );
  const handleDoneChange = useCallback(
    (id: string, done: boolean) => notify("update_done", id, done),
    [socket]
  );
  return (
    <div>
      <p>Socket: {state}</p>
      {list ? (
        <Fragment>
          <List list={list} onDoneChange={handleDoneChange} />
          <Form onSubmit={handleSubmit} />
        </Fragment>
      ) : (
        <p>Loading...</p>
      )}
    </div>
  );
}
