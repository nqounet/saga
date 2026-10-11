# Rules

## Changelog
- CHANGELOG.md への記録は日本語を使用せず、すべて英語で記述してください。

## Build
- `swift build` が `Unknown error parsing property list` で失敗したら、まず `xcode-select -p` と `ls /Applications | grep Xcode` を確認する。Command Line Tools のみの環境では、SwiftUI を含むアプリ本体はビルドできない（`--build-system native` は SwiftUIMacros が無く通らない）。キャッシュ削除やビルドシステム切替を試さず、Xcode が必要と報告する。
- テストが `--build-system native` で通っても、アプリ本体がビルドできる根拠にはならない（テストは SwiftUI を使わない）。
