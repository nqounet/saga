---
name: release-version
description: saga プロジェクト向けにリリースバージョンを上げる（パッチ、マイナー、メジャー）ための具体的な手順。
---

# saga プロジェクト用リリースバージョンアップ手順

このスキルは、[saga](file:///Users/nobu/local/src/github.com/nqounet/saga) プロジェクト固有のリリース手順を定義します。基本的なフローはグローバルスキル `release-version` に従い、以下の固有のルールを必ず適用してください。

## 🚨 saga 固有のルール

### 1. バージョン定義ファイルの更新
saga プロジェクトでバージョンを更新する際は、以下のファイルを必ず修正する必要があります。
- **対象ファイル**: [Sources/SagaCore/SagaCore.swift](file:///Users/nobu/local/src/github.com/nqounet/saga/Sources/SagaCore/SagaCore.swift)
- **修正内容**: `public static let version` に定義されているバージョン文字列を、新しくリリースするバージョンに変更します。
  ```swift
  public struct SagaCore {
      public static let version = "<新バージョン>"
  }
  ```

> [!IMPORTANT]
> このファイル（`SagaCore.swift`）の変更が GitHub Actions のリリースワークフロートリガー条件になっています。このファイルを修正しないと、マージ後にワークフローが起動しません。

### 2. CHANGELOG.md の更新
- **対象ファイル**: [CHANGELOG.md](file:///Users/nobu/local/src/github.com/nqounet/saga/CHANGELOG.md)
- グローバルスキルの手順に従い、追加/変更された内容を記述します。

### 3. ビルドの検証
バージョン変更後、以下のコマンドを実行してビルドが通ることを確認してください。
```bash
swift build
```

### 4. PR作成とマージ
1. `release/v<バージョン>` ブランチをプッシュします。
2. GitHub CLI を使用して PR を作成します。
3. PR のマージ後、しばらく待ってから `git fetch --tags` を実行し、該当の `v<バージョン>` タグがリモートから取得できるか（＝リリースワークフローが正常に実行され、完了したか）を確認してください。
