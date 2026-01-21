# CHANGELOG

## 0.3.3

### Features

- Adds support for optional topic parameters.

## 0.3.1

### Fixes

- Update JavaScript client version to only notify initial topic if loaded.

## 0.3.0

### Improvements

- `useTopic` now returns stale value, along with an `error` and `loading` properties.

## 0.2.0

### Improvements

- Updated core dependency to add support for merge operations.

## 0.1.9

### Fixes

- Ignores messages for a subscription that has been unsubscribed.

## 0.1.8

### Fixes

- Handles applying nested update to undefined topic state.

## 0.1.7

### Fixes

- Correctly sets initial socket state.

## 0.1.6

### Improvements

- Updates core dependency (to pass topics as lists).

## 0.1.5

### Fixes

- Ensures the value returned by `useTopic` always corresponds to the specified topic.
