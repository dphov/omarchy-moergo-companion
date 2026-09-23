# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.4] - 2026-09-23

### Added

- build(dev): add `dev.sh` for installing locally-built binaries without remote downloads
- build(just): run `dev` (local install) by default instead of `install` (release download)

### Changed

- build(just): rename `just dev` file watcher recipe to `just watch`

## [1.2.3] - 2026-09-23

### Fixed

- build(install): restore executable bit on `install.sh`

## [1.2.2] - 2026-09-22

### Changed

- ci(release): require tarball digest committed before the tag
- ci(release): verify published tarball digest matches install.sh
- ci(release): add SOURCE_DATE_EPOCH file for deterministic tarball mtime
- ci(release): fix changelog output block syntax
## [1.2.1] - 2026-09-22

### Changed

- ci(release): deterministic and reproducible release tarball packaging
- ci(release): auto-pin release tarball digest on publish
- refactor(qml): clean up unused imports and duplicate properties
- refactor(qml): remove dead isActive property and simplify KeyCap styling
- build(qml): use explicit .qmltypes files in strict qml lint script

### Fixed

- fix(install): bind release tarballs to committed digests and harden transfer bounds

### Documentation

- docs(readme): update security and install docs for committed digest model


## [1.2.0] - 2026-09-21

### Security

- fix(service,watcher): remove `Service.qml` runtime directory computation and the watcher `output_json` argument
- fix(service): no `/tmp` string remains in QML; the watcher emits layout JSON on stdout, so components never need to read a shared file

### Documentation

- docs(readme): sync security/provenance docs for v1.2.0
- docs(install): document reproducible digest review procedure

## [1.1.9] - 2026-09-21

### Security

- fix(ci): sign Sigstore attestations for the downloadable tarball and outer `SHA256SUMS` instead of the staging directory

## [1.1.8] - 2026-09-21

### Security

- fix(runtime): never use `/tmp` for the secure runtime directory; rely only on `XDG_RUNTIME_DIR` or `~/.cache/omarchy/moergo-companion/runtime`
- fix(service): require `XDG_RUNTIME_DIR` in `Service.qml` instead of falling back to a `/tmp` path

## [1.1.7] - 2026-09-21

### Fixed

- fix(service): make auto-bootstrap idempotent to stop "Installing…"/"No binaries" flicker
- fix(install): add `--ensure` flag so `Service.qml` can run `install.sh` on every startup without re-downloading
- fix(service): remove unreliable `XMLHttpRequest` file check and guard bootstrap with `bootstrapInProgress`

## [1.1.6] - 2026-09-21

### Added

- feat(service): auto-bootstrap native helpers on first run from `Service.qml` so `omarchy plugin add` works without manual `install.sh`

## [1.1.5] - 2026-09-21

### Fixed

- fix(ci): package release tarball with binaries flat in the archive so extraction lands directly in `bin/`
- fix(ci): fail `install.sh` download path when checksum verification does not pass

## [1.1.4] - 2026-09-21

### Fixed

- fix(ci): package release tarball with `bin/` subdirectory to avoid `SHA256SUMS` name collision
- fix(ci): verify downloaded release binaries against internal `bin/SHA256SUMS`
- docs: update README and release notes for unambiguous two-step tarball verification

## [1.1.3] - 2026-09-21

### Changed

- refactor(ci): distribute binaries via release assets only

### Fixed

- fix(ci): distribute binaries as single tarball with arch gate

## [1.1.2] - 2026-09-21

### Fixed

- fix(ci): harden supply chain and remove distributed AGENTS.md

### Documentation

- docs: add agent authorization rules

## [1.1.1] - 2026-09-17

### Changed

- style: apply cargo fmt
- chore: add pre-commit hook and just check/commit recipes
- refactor(justfile): rename release recipes to action-based names

## [1.1.0] - 2026-09-17
Security focused release for passing the omarchy plugin team validation

### Added

- feat: harden runtime paths with mode-0700 symlink defense and add automated tag-based release workflow
- feat(justfile): add sha and verify-sha recipes for binary integrity
- feat(justfile): auto-generate categorized CHANGELOG.md on release-bump
- feat(justfile): add release-bump-dry to preview next changelog

### Changed

- chore: add release recipe to justfile
- chore: remove internal docs and specifications
- ci: enforce GitHub Actions as sole verified binary builder with local bin ignore
- chore(justfile): use --locked in tests, decouple install from build, fix dev watcher
- ci(release): embed SHA-256 checksums in release body and keep SHA256SUMS asset
- ci(release): simplify checksum/archive step with working-directory
- ci: split CI/build/release responsibilities
- chore(justfile): add dry-run-release recipe and fix self-checksum bug
- chore(justfile): add semantic-version release-bump helper
- ci(release): inject matching CHANGELOG.md section into release body
- refactor(justfile): simplify release workflow to hybrid changelog

### Fixed

- fix(security): prevent non-ASCII slice panic, preserve UTF-8, and reap child processes
- fix(parser): strip layer_ prefix from layer names, map ZMK keycode aliases, and strip UUID from title
- fix(ui): increase button size, enable dynamic matrix scaling, and prevent single-word wrap

### Documentation

- docs: document binary provenance, locked-source builds, and SHA-256 verification
- docs: prioritize ./install.sh and omarchy plugin installer for end users, just for developers

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
