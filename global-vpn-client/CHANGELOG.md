# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## [4.10.8] - 2023-07-19

### Added

- Version 4.10.8 installer

## [4.10.8.20261001] - 2026-10-01

### Fixed

- Install is now silent: the installer is a WinRAR self-extractor, so `-s` keeps extraction silent and `-sp` passes `/qn /norestart` to the bundled MSI
- Uninstaller now finds the program (registered as `Global VPN Client`) and removes it by its MSI product code
