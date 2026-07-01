# Git ワークフロー

## コミットメッセージ形式

```
<type>: <description>
```

タイプ: feat, fix, refactor, docs, test, chore, perf, ci, build, style

プロジェクトに commitlint 設定がある場合はそちらを優先する。

## コミットルール

- 1 コミット 1 論理変更（複数の機能・修正を混ぜない）
- 大きな変更は機能単位・変更種別で分割してコミット
- コミットメッセージの言語はプロジェクトの既存コミット履歴に合わせる

## プッシュ・PR ルール

- 新規ブランチの場合は `-u` フラグ付きでプッシュ
- デフォルトブランチに直接コミット・プッシュしない
- PR 作成時は全コミット履歴を分析し、包括的なサマリーを作成

## 機能実装ワークフロー

1. **発想**: `superpowers:brainstorming` スキルで要件・意図・設計を探索
2. **計画**: `superpowers:writing-plans` スキルで実装計画を作成（依存関係・リスク特定、フェーズ分割）
3. **TDD**: `superpowers:test-driven-development` スキルで RED → GREEN → REFACTOR サイクル
4. **実行**: `superpowers:executing-plans` スキルでレビューチェックポイント付き実装
5. **レビュー**: `superpowers:requesting-code-review` スキルで品質チェック
6. **完了検証**: `superpowers:verification-before-completion` スキルで成功宣言前に検証
7. **コミット**: `/commit` で論理単位に分割してコミット（push + PR まで一気通貫する場合は `/commit-push-pr`）

## アトリビューション

~/.claude/settings.json でグローバルに無効化済み。
