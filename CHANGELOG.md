# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-16

### Added

- `Service.qml` background service for shared state and process orchestration.
- Plugin manifest now declares both `service` and `bar-widget` kinds.
- `preview.png` for Omarchy marketplace / repository preview.
- `CHANGELOG.md`.

### Changed

- `MoErgoCompanion.qml` refactored to bind to the service instead of running processes directly.
- Hardware monitoring, keymap watching, settings persistence, and dashboard actions moved into the service so multiple widget instances share one backend.
- README rewritten with service/widget architecture, development commands, configuration, troubleshooting, and icon attributions.

### Fixed

- Layer reset behavior now lives in the service and triggers consistently when the keymap file changes.

## Earlier commits

Pre-release development included the Rust keymap parser, Glove80 matrix visualizer, layer tabs, dashboard, hardware status polling, and low-battery notifications.
