# claude-daily-report

Claude Code の `/daily` コマンドで、Slack・Notion・Google Calendar・Codex・Claude Code のログを自動収集し、分析型の日報を生成・投稿するツール。

## 特徴

- **マルチソース収集**: Slack（メッセージ・メンション）、Notion（ドキュメント・議事録）、Google Calendar、Codex/Claude Code セッションログを並列取得
- **インパクト分析**: チャンネル別ではなくインパクト順で主要アウトプットを整理
- **議事録統合**: Notion の議事録DBから決定事項・アクションアイテムを自動抽出し、カレンダーと突合
- **時間推定**: Slack メッセージクラスタリング + カレンダー + Notion編集履歴から稼働時間を推定
- **自動実行**: macOS LaunchAgent で毎日定時に自動投稿（オプション）

## 前提条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) がインストール済み
- Slack MCP server が設定済み（[claude-mcp-slack](https://github.com/anthropics/claude-mcp-slack)）
- Notion MCP server が設定済み（[claude-mcp-notion](https://github.com/anthropics/claude-mcp-notion)）
- Python 3.8+

### オプション

- [slack-crawler](https://github.com/nicokosi/slack-crawler) の SQLite DB（過去14日のベースライン比較に使用）
- Google Calendar OAuth トークン（`~/.clasprc.json`）
- [Codex](https://github.com/openai/codex) のセッションログ（`~/.codex/sessions/`）

## セットアップ

```bash
git clone https://github.com/rikogohda-cloud/claude-daily-report.git
cd claude-daily-report
bash setup.sh
```

`setup.sh` が対話的に以下を聞いて、ファイルを配置します:

| 設定項目 | 説明 |
|----------|------|
| Slack User ID | あなたの Slack ユーザーID（例: `U07E74J2GEM`） |
| Slack Handle | あなたの Slack ハンドル（例: `john.doe`） |
| 表示名 | 日報に表示される名前 |
| 投稿先チャンネルID | 日報を投稿する Slack チャンネルの ID |
| times系チャンネル名 | 集計から除外する自分の times チャンネル |
| Slack Crawler DB パス | SQLite DB のパス（空欄でスキップ可） |
| 議事録 Notion DB ID | 議事録が溜まる Notion データベースの ID（空欄でスキップ可） |

## 使い方

### 対話モード

Claude Code で `/daily` を実行:

```
> /daily
```

日報が生成され、内容を確認してから投稿できます。

### 自動モード

セットアップ時に LaunchAgent を設定した場合、毎日 21:00 に自動実行されます。

```bash
# 手動で自動モードを実行
~/bin/run-daily-report.sh

# ログ確認
tail -f ~/Library/Logs/daily-report.log
```

## 日報の構成

| セクション | 内容 |
|-----------|------|
| A. スコアカード | 稼働時間、アクティビティ件数、議事録カバー率 |
| B. 主要アウトプット | インパクト順（高→中→低）で整理。Slack + Notion + 議事録 |
| C. 時間配分 | カテゴリ別プログレスバー + 先週比 |
| D. 振り返り | ヒヤリハット、プロセス改善、好事例 |
| E. 明日の優先度 | 未返信 + 未完了 + 議事録AIからインパクト順で最大7件 |
| F. 詳細ログ | カテゴリ別の全活動ログ（スレッド返信） |

## カスタマイズ

`~/.claude/daily-worker.md` の「設定」セクションを編集して、以下をカスタマイズできます:

- **アクティビティ分類**: 自分の業務に合わせたカテゴリと判定基準
- **除外対象**: レポートから除外するメッセージパターン
- **振り返りトーン**: `strict`（率直に指摘）/ `neutral`（事実を整理）/ `question`（問いかけ形式）

## ファイル構成

```
~/.claude/
├── commands/
│   └── daily.md              # /daily コマンド定義
└── daily-worker.md            # ワーカー指示書（設定もここ）

~/bin/
├── run-daily-report.sh        # 自動実行スクリプト
└── fetch-calendar.py          # Google Calendar 取得

~/Library/LaunchAgents/
└── com.<user>.daily-report.plist  # 定時実行（オプション）
```

## License

MIT
