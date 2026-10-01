# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## [2.2] - 2022-08-29

### Added

- Version 2.2 installer

## [2.2.0.20261001] - 2026-10-01

### Fixed

- Install is now silent: the installer is Inno Setup, but the package passed InstallShield switches, so it ran interactively
- Uninstaller now runs the Inno Setup uninstaller instead of applying MSI product-code logic
