# セットアップ完全ガイド

## 前提条件

### 必須
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) インストール済み
- Slack MCP server 設定済み（[claude-mcp-slack](https://github.com/anthropics/claude-mcp-slack)）
- Notion MCP server 設定済み（[claude-mcp-notion](https://github.com/anthropics/claude-mcp-notion)）
- Python 3.8+

### オプション
- Google Calendar OAuth トークン（`~/.clasprc.json`）
- [slack-crawler](https://github.com/nicokosi/slack-crawler) の SQLite DB

## 初回セットアップ

### 1. リポジトリをクローン
```bash
cd ~/repos
git clone https://github.com/rikogohda-cloud/claude-daily-report.git
cd claude-daily-report
```

### 2. セットアップスクリプトを実行
```bash
bash setup.sh
```

以下の情報を入力：
- Slack User ID（例: U07E74J2GEM）
- Slack Handle（例: riko.gohda）
- 表示名（例: Riko Gohda）
- 投稿先チャンネルID（例: C0AFMNT8PAS）
- times系チャンネル名（例: times_riko）
- Slack Crawler DBパス（オプション、空欄でスキップ）
- 議事録 Notion DB ID（例: 30d93c7ce32d8014a26ff8583dfadc9e）

### 3. 設定確認
```bash
ls -la ~/.claude/commands/daily.md
ls -la ~/.claude/daily-worker.md
```

## 削除された場合の復元手順

### 方法1: セットアップスクリプトを再実行（推奨）
```bash
cd ~/repos/claude-daily-report
git pull origin master  # 最新版を取得
bash setup.sh
```

### 方法2: 手動で復元
```bash
cd ~/repos/claude-daily-report
git pull origin master

# ファイルをコピー
cp .claude/commands/daily.md ~/.claude/commands/daily.md
cp .claude/daily-worker.md ~/.claude/daily-worker.md

# プレースホルダーを置換（YOUR_* を実際の値に置き換える）
sed -i '' \
  -e 's/__SLACK_USER_ID__/YOUR_SLACK_USER_ID/g' \
  -e 's/__SLACK_HANDLE__/YOUR_SLACK_HANDLE/g' \
  -e 's/__USER_DISPLAY_NAME__/YOUR_DISPLAY_NAME/g' \
  -e 's/__POST_CHANNEL_ID__/YOUR_CHANNEL_ID/g' \
  -e 's/__TIMES_CHANNEL_NAME__/YOUR_TIMES_CHANNEL/g' \
  -e 's/__MEETING_NOTES_DB_ID__/YOUR_NOTION_DB_ID/g' \
  ~/.claude/commands/daily.md ~/.claude/daily-worker.md
```

### 方法3: バックアップから復元
```bash
cp ~/.claude/commands/daily.md.backup ~/.claude/commands/daily.md
cp ~/.claude/daily-worker.md.backup ~/.claude/daily-worker.md
```

## 設定値の確認方法

### 現在の設定を表示
```bash
head -20 ~/.claude/commands/daily.md
head -20 ~/.claude/daily-worker.md
```

確認項目：
- Slack User ID
- Slack Handle
- 投稿先チャンネルID
- 議事録 Notion DB ID

### 設定値の取得方法

#### Slack User ID
```bash
# Slack MCPで自分のメッセージを検索
# UserID列に表示される
```
または Slack設定 > プロフィール > その他 > メンバーIDをコピー

#### Slack チャンネルID
```bash
# Slackでチャンネルを開く
# URLの最後の部分（例: C0AFMNT8PAS）
```

#### Notion DB ID
```bash
# NotionでDBを開く
# URLの "?v=" の前の32桁（例: 30d93c7ce32d8014a26ff8583dfadc9e）
```

## トラブルシューティング

### `/daily` コマンドが見つからない
```bash
# ファイルが存在するか確認
ls -la ~/.claude/commands/daily.md

# 存在しない場合は復元（上記参照）
```

### トークン消費量が多すぎる
- 現在の設定: Sonnet、月20回で130万トークン（6.5％）
- Haikuに切り替える場合: `~/.claude/commands/daily.md` の22行目を `model: haiku` に変更

### Notion DBが見つからない
```bash
# Notion MCP serverが設定されているか確認
cat ~/.config/claude/config.json | grep notion
```

### Slackに投稿されない
```bash
# Slack MCP serverが設定されているか確認
cat ~/.config/claude/config.json | grep slack

# チャンネルIDが正しいか確認
head -15 ~/.claude/commands/daily.md
```

## 定期実行の設定（オプション）

### LaunchAgent（macOS）
```bash
# setup.sh 実行時に設定を選択
# または手動で設定:
cp launchagent/com.daily-report.plist.template ~/Library/LaunchAgents/com.$(whoami).daily-report.plist

# プレースホルダーを置換
# 読み込み
launchctl load ~/Library/LaunchAgents/com.$(whoami).daily-report.plist
```

### 実行ログの確認
```bash
tail -f ~/Library/Logs/daily-report.log
```

## 設定ファイルのバックアップ

### 自動バックアップ（推奨）
```bash
# .zshrc または .bashrc に追加
alias backup-daily="cp ~/.claude/commands/daily.md ~/.claude/commands/daily.md.backup && cp ~/.claude/daily-worker.md ~/.claude/daily-worker.md.backup && echo 'Backup created'"

# 実行
backup-daily
```

### 手動バックアップ
```bash
cp ~/.claude/commands/daily.md ~/.claude/commands/daily.md.backup
cp ~/.claude/daily-worker.md ~/.claude/daily-worker.md.backup
```

## カスタマイズ

### アクティビティ分類を変更
`~/.claude/daily-worker.md` の「アクティビティ分類カスタマイズ」セクションを編集

### 振り返りトーンを変更
`~/.claude/daily-worker.md` の設定セクション:
```markdown
| 振り返りトーン | strict |
```

値: `strict`（率直に指摘）/ `neutral`（事実を整理）/ `question`（問いかけ形式）

### 投稿先チャンネルを変更
`~/.claude/commands/daily.md` の13行目を編集

## 更新手順

### 最新版を取得
```bash
cd ~/repos/claude-daily-report
git pull origin master
```

### 設定を保持したまま更新
```bash
# 現在の設定をバックアップ
cp ~/.claude/commands/daily.md /tmp/daily.md.backup
cp ~/.claude/daily-worker.md /tmp/daily-worker.md.backup

# 最新版を取得
cd ~/repos/claude-daily-report
git pull origin master

# 新しいテンプレートに設定を反映（手動で値をコピー）
# または setup.sh を再実行
```

## よくある質問

### Q: 削除されたらどうすればいい？
A: `cd ~/repos/claude-daily-report && git pull && bash setup.sh` で復元

### Q: トークン消費量を減らしたい
A: `~/.claude/commands/daily.md` の22行目を `model: haiku` に変更

### Q: 実行頻度を変えたい
A: LaunchAgentの設定ファイル（`~/Library/LaunchAgents/com.*.daily-report.plist`）を編集

### Q: 複数ユーザーで使いたい
A: ユーザーごとに異なる設定でセットアップ可能。同じリポジトリから `setup.sh` を実行

## サポート

問題が発生した場合：
1. このガイドのトラブルシューティングを確認
2. [TOKEN-OPTIMIZATION-v2.md](TOKEN-OPTIMIZATION-v2.md) でトークン消費量を確認
3. GitHubリポジトリのIssuesで報告
