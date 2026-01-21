# CHANGELOG

## 0.3.0

### Featuyres

- Adds support for topics to have optional parameters (with defaults; in addition to required route parameters).

### Improvements

- Updates `subscribe`/`unsubscribe` to avoid unnecessarily initialising topic to unsubscribe.

## 0.2.4

### Features

- Adds `authorize/2` callback for controlling access to topics based on context.

## 0.2.3

### Improvements

- Fixes deprecation warning.

## 0.2.2

### Improvements

- Handles and returns init errors.

## 0.2.1

### Fixes

- Handles merging into an undefined value.

## 0.2.0

### Features

- Adds support for merge operation.

## 0.1.12

### Improvements

- If, after applying topic updates, the value of a topic hasn't changed, the updates will be discarded.

## 0.1.11

### Improvements

- Topic routes are specified as a list (e.g., `["lists", :list_id]`), rather than a string (`"lists/:list_id"`).

## 0.1.10

### Features

- Adds a WebSock/Plug adapter.

## 0.1.9

### Improvements

- Empty updates (and inserts) are ignored, which avoids sending unnecessary messages to clients.

## 0.1.8

### Fixes

- Fixes the order of updates.

## 0.1.7

### Features

- Adds support for 'capturing' the state of a topic, without subscribing. And another Cowboy adapter for adding a REST-like handler for getting the current state of a topic.

### Improvements

- More useful errors are raised when a callback doesn't return an expected result.

### Fixes

- Fixes a race condition when a topic is started.
