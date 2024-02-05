import * as React from "react";
import { ChangeEvent, FormEvent, Fragment, useCallback, useState } from "react";

import { SocketProvider, useTopic, useSocket } from "@topical/react";
import * as models from "../models";

type ItemProps = {
  item: models.Item;
  itemId: string;
  onDoneChange: (id: string, done: boolean) => void;
  onTextUpdate: (id: string, text: string) => void;
};

function Item({ item, itemId, onDoneChange, onTextUpdate }: ItemProps) {
  const { text, done } = item;
  const handleDoneChange = useCallback(
    (ev: ChangeEvent<HTMLInputElement>) => {
      onDoneChange(itemId, ev.target.checked);
    },
    [itemId, onDoneChange],
  );
  const handleDoubleClick = useCallback(() => {
    const newText = prompt("Update item:", item.text);
    if (newText && newText != text) {
      onTextUpdate(itemId, newText);
    }
  }, [text, onTextUpdate]);
  return (
    <div className="item">
      <input
        type="checkbox"
        checked={done || false}
        onChange={handleDoneChange}
      />
      <span onDoubleClick={handleDoubleClick}>{text}</span>
    </div>
  );
}

type ItemsProps = {
  list: models.List;
  onDoneChange: (id: string, done: boolean) => void;
  onTextUpdate: (id: string, text: string) => void;
};

function Items({ list, onDoneChange, onTextUpdate }: ItemsProps) {
  return (
    <ol>
      {list.order.map((id: string) => (
        <li key={id}>
          <Item
            item={list.items[id]}
            itemId={id}
            onDoneChange={onDoneChange}
            onTextUpdate={onTextUpdate}
          />
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
    [],
  );
  const handleSubmit = useCallback(
    (ev: FormEvent<HTMLFormElement>) => {
      ev.preventDefault();
      onSubmit(text).then(() => {
        setText("");
      });
    },
    [text],
  );
  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        placeholder="Add an item..."
        value={text}
        onChange={handleChange}
      />
    </form>
  );
}

type ListProps = {
  id: string;
  name: string;
};

function List({ id, name }: ListProps) {
  const [list, { execute, notify }] = useTopic<models.List>("lists", id);
  const handleSubmit = useCallback(
    (text: string) => execute("add_item", text),
    [execute],
  );
  const handleDoneChange = useCallback(
    (id: string, done: boolean) => notify("update_done", id, done),
    [notify],
  );
  const handleTextUpdate = useCallback(
    (id: string, text: string) => notify("update_text", id, text),
    [notify],
  );
  return (
    <div className="list">
      <h1>{name}</h1>
      {list ? (
        <Fragment>
          <Items
            list={list}
            onDoneChange={handleDoneChange}
            onTextUpdate={handleTextUpdate}
          />
          <Form onSubmit={handleSubmit} />
        </Fragment>
      ) : (
        <p>Loading...</p>
      )}
    </div>
  );
}

function Lists() {
  const [lists, { execute }] =
    useTopic<{ id: string; name: string }[]>("lists");
  const handleAddClick = useCallback(() => {
    const name = prompt("Enter list name:");
    if (name) {
      execute("add_list", name).catch(() => {
        alert("Failed to add list. Please try again.");
      });
    }
  }, [execute]);
  if (lists) {
    return (
      <ul className="lists">
        {lists.map(({ id, name }) => (
          <li key={id}>
            <List id={id} name={name} />
          </li>
        ))}
        <li>
          <button onClick={handleAddClick}>+</button>
        </li>
      </ul>
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
  return (
    <SocketProvider url={`ws://${window.location.host}/socket`}>
      <div>
        <SocketStatus />
        <Lists />
      </div>
    </SocketProvider>
  );
}
