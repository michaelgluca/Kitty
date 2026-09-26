# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Repository foundations: `.gitignore` as the first commit, Apache-2.0 licence, `NOTICE`,
  trade mark policy, contributing guide, code of conduct and security policy.
- Architecture Decision Records under `docs/adr`.
- CI guards that fail the build on any third-party dependency, any networking symbol, any
  force unwrap in shipping code, `telprompt:`, a hardcoded emergency number, or a reference to a
  known-hostile emergency domain.
- A weekly scheduled check that every outbound URL shipped in the app still resolves.

### Notes
- This is a rebuild. The 2023 MSc dissertation proof of concept is preserved on the
  `archive/dissertation-2023` branch and is not the basis of this history. See ADR-0001.
