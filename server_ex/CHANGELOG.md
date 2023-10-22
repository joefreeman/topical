# CHANGELOG

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
