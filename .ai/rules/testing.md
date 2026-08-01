# テスト要件

## 最低テストカバレッジ: 80%

テストタイプ（**すべて**必須）:
1. **ユニットテスト** - 個別の関数、ユーティリティ、コンポーネント
2. **インテグレーションテスト** - APIエンドポイント、データベース操作
3. **E2Eテスト** - 重要なユーザーフロー、UIインタラクション（Playwright推奨）

## テスト駆動開発

**必須**ワークフロー:
1. まずテストを書く（RED）
2. テストを実行 - 失敗すべき
3. 最小限の実装を書く（GREEN）
4. テストを実行 - パスすべき
5. リファクタリング（IMPROVE）
6. カバレッジを確認（80%以上）

## テスト失敗のトラブルシューティング

1. `superpowers:systematic-debugging` スキルで体系的に調査
2. テストの分離を確認
3. モックが正しいか確認
4. 実装を修正（テストが間違っている場合を除く）

## スキルサポート

### 標準スキル (Superpowers)
- `superpowers:test-driven-development` - 新機能・バグ修正時に**積極的に**使用、テストファースト強制
- `superpowers:systematic-debugging` - テスト失敗やバグ調査時に使用
- `superpowers:verification-before-completion` - 完了宣言前の検証に使用

### ローカル拡張スキル (dotfiles)
- `rspec-tdd` - Rails / RSpec プロジェクトでのテスト駆動開発の手順やプロンプトとして利用
- `e2e-testing` - Playwrightを用いたE2Eテストの設計（Page Object Model等）やFlaky対策時に参照
- `playwright-cli` - E2Eテスト作成中に、ブラウザを開いてUIセレクタを調査・デバッグする際に必ず使用
