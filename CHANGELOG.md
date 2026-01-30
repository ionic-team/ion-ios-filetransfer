# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 2026-01-26

- Fix: Return error response body on HTTP error in upload or download.
- Fix: Only notify of progress when HTTP code is successful.

## 1.0.1

### 2025-08-01

- Fix progress notification for `uploadFile`.
- Fix error (only visible in logs) related to `chunkedMode` and `httpBodyStream`.

## 1.0.0

### 2025-04-14

- Implement native library with methods `downloadFile` and `uploadFile`.
