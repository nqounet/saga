# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-06-30

### Added
- アプリのアイコン追加と Saga.app パッケージング用のビルドスクリプトを追加 (#11)
- 開発およびプロダクションビルド用の mise タスクを追加 (#11)

### Changed
- 実際の変更内容を反映して README.md を更新 (#10)
- アプリのアイコンをフラットデザインに変更し、背景を透過処理 (#11)

### Fixed
- リソース検索時の大文字小文字の区別を解決し、miseタスクの実行を修正 (#11)

## [0.1.3] - 2026-06-30

### Changed
- 2ページ表示時の画像配置の調整および仕切り線（divider）の削除 (#8)

### Fixed
- `AsyncImageView` 内の `Image` に直接画像配置（alignment）を適用するよう修正 (#8)

## [0.1.2] - 2026-06-30

### Fixed
- 「1枚ずらす」機能の動作仕様の変更 (#6)
- 不要なコードの削除 (page shifting logic)

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
