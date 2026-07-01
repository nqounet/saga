# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-07-01

### Changed
- Localize UI and documentation to English (#17)
- Localize CHANGELOG.md to English and enforce English language rule (#18)

### Fixed
- Address review feedback on localization in ContentView.swift (#17)

## [0.3.0] - 2026-07-01

### Added
- Support folder selection via drag and drop (#15)
- Implement `showsCoverPage` (show cover page) and center alignment for single pages (#14)
- Add visibility toggle for status bar and toolbar (#13)

### Changed
- Localize menu items to English and integrate into standard View menu (#13)

### Refactored
- Simplify nested if statements in `getStepSize` (#14)
- Remove status bar toggle button from control panel and integrate it (#13)

## [0.2.0] - 2026-06-30

### Added
- Add app icon and build script for Saga.app packaging (#11)
- Add mise tasks for development and production builds (#11)

### Changed
- Update README.md to reflect actual changes (#10)
- Change app icon to flat design and transparentize the background (#11)

### Fixed
- Resolve case sensitivity in resource lookup and fix execution of mise tasks (#11)

## [0.1.3] - 2026-06-30

### Changed
- Adjust image placement in two-page view and remove divider line (#8)

### Fixed
- Fix to apply image alignment directly to `Image` within `AsyncImageView` (#8)

## [0.1.2] - 2026-06-30

### Fixed
- Change operation specification for "shift page by one" feature (#6)
- Remove unused code (page shifting logic)

## [0.1.1] - 2026-06-30

### Added
- Release automation workflow (#3)

### Changed
- Removed toolbar menu titles and added dividers for better visual structure (#4)

## [0.1.0] - 2026-06-30

### Added
- SPM-based SAGA macOS SwiftUI viewer application (#1)

### Changed
- Performance and concurrency improvements for the viewer based on code review feedback.
