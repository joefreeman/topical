import * as React from "react";
import { ChangeEvent, FormEvent, Fragment, useCallback, useState } from "react";

import { SocketProvider, useTopic, useSocket } from "../topical";
import * as models from "../models";

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

type ItemsProps = {
  list: models.List;
  onDoneChange: (id: string, done: boolean) => void;
};

function Items({ list, onDoneChange }: ItemsProps) {
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

type ListProps = {
  name: string;
};

function List({ name }: ListProps) {
  const topic = `lists/${name}`;
  const [list, { execute, notify }] = useTopic<models.List>(topic);
  const handleSubmit = useCallback(
    (text: string) => execute("add_item", text),
    [execute]
  );
  const handleDoneChange = useCallback(
    (id: string, done: boolean) => notify("update_done", id, done),
    [notify]
  );
  return (
    <div>
      {list ? (
        <Fragment>
          <Items list={list} onDoneChange={handleDoneChange} />
          <Form onSubmit={handleSubmit} />
        </Fragment>
      ) : (
        <p>Loading...</p>
      )}
    </div>
  );
}

function SocketStatus() {
  const [_socket, state] = useSocket();
  return <p>Socket: {state}</p>;
}

export default function App() {
  return (
    <SocketProvider url={`ws://${window.location.host}/socket`}>
      <div>
        <SocketStatus />
        <List name="foo" />
        <List name="bar" />
      </div>
    </SocketProvider>
  );
}
