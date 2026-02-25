# Changelog

## 2026-02-25

### Added
- TOKEN-OPTIMIZATION-v2.md: トークン最適化設計（質を保つアプローチ）
- SETUP-GUIDE.md: セットアップ完全ガイド
- CHANGELOG.md: 変更履歴

### Changed
- 出力最適化ルールを daily-worker.md に追加
  - 絵文字を最小限に（■●○・!+✓）
  - 簡潔な表現
  - 詳細ログは各カテゴリ最大3件
  - 出力トークン上限: 30,000トークン
- プログレスバーを維持（ユーザー要望）
- daily.md にモデル選択コメント追加（sonnet / haiku）

### Fixed
- 実行頻度を月30回→月20営業日に修正
- トークン消費量の計算を修正（270万→130万トークン）

### Decision
- モデル: Sonnet（Haikuは不要）
- 想定消費量: 65k × 20 = 130万トークン（6.5％/月）
- 目標3〜4.5％は若干超えるが、品質を優先してSonnetで運用

## 2026-02-21

### Added
- Initial release
- `/daily` コマンド実装
- Slack/Notion/Google Calendar/Codex/Claude Code統合
- 自動実行（LaunchAgent）サポート

### Features
- マルチソース収集（Slack、Notion、カレンダー、ログ）
- インパクト分析（高→中→低で整理）
- 議事録統合（Notion DB連携）
- 時間推定（Slackクラスタリング + カレンダー）
- 振り返り自動生成（ヒヤリハット、プロセス改善、好事例）
