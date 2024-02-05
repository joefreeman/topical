# CHANGELOG

## 0.2.0

### Improvements

- Added support for merge operation.

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
