#!/bin/bash
# claude-daily-report セットアップスクリプト
# 対話的に設定値を入力し、ファイルを配置する

set -euo pipefail

echo "=== claude-daily-report セットアップ ==="
echo ""

# --- 設定値の入力 ---

read -rp "Slack User ID (例: U07E74J2GEM): " SLACK_USER_ID
read -rp "Slack Handle (例: john.doe): " SLACK_HANDLE
read -rp "表示名 (例: John Doe): " USER_DISPLAY_NAME
read -rp "投稿先チャンネルID (例: C0AFMNT8PAS): " POST_CHANNEL_ID
read -rp "times系チャンネル名（除外用, 例: times_john）: " TIMES_CHANNEL_NAME

read -rp "Slack Crawler DBパス (空欄でスキップ): " SLACK_CRAWLER_DB_PATH
SLACK_CRAWLER_DB_PATH="${SLACK_CRAWLER_DB_PATH:-}"

read -rp "議事録 Notion DB ID (空欄でスキップ): " MEETING_NOTES_DB_ID
MEETING_NOTES_DB_ID="${MEETING_NOTES_DB_ID:-}"

echo ""
echo "--- 入力内容 ---"
echo "Slack User ID:       $SLACK_USER_ID"
echo "Slack Handle:        $SLACK_HANDLE"
echo "表示名:              $USER_DISPLAY_NAME"
echo "投稿先チャンネルID:  $POST_CHANNEL_ID"
echo "times系チャンネル:   $TIMES_CHANNEL_NAME"
echo "Slack Crawler DB:    ${SLACK_CRAWLER_DB_PATH:-(未設定)}"
echo "議事録 Notion DB:    ${MEETING_NOTES_DB_ID:-(未設定)}"
echo ""

read -rp "この内容で設定しますか？ (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "中断しました。"
    exit 0
fi

# --- ファイル配置 ---

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# プレースホルダー置換関数
replace_placeholders() {
    local file="$1"
    local tmpfile
    tmpfile=$(mktemp)
    sed \
        -e "s|__SLACK_USER_ID__|${SLACK_USER_ID}|g" \
        -e "s|__SLACK_HANDLE__|${SLACK_HANDLE}|g" \
        -e "s|__USER_DISPLAY_NAME__|${USER_DISPLAY_NAME}|g" \
        -e "s|__POST_CHANNEL_ID__|${POST_CHANNEL_ID}|g" \
        -e "s|__TIMES_CHANNEL_NAME__|${TIMES_CHANNEL_NAME}|g" \
        -e "s|__SLACK_CRAWLER_DB_PATH__|${SLACK_CRAWLER_DB_PATH}|g" \
        -e "s|__MEETING_NOTES_DB_ID__|${MEETING_NOTES_DB_ID}|g" \
        -e "s|__HOME__|${HOME}|g" \
        -e "s|__YOUR_USERNAME__|$(whoami)|g" \
        "$file" > "$tmpfile"
    mv "$tmpfile" "$file"
}

echo ""
echo "ファイルを配置中..."

# 1. Claude Code commands
mkdir -p ~/.claude/commands
cp "$SCRIPT_DIR/.claude/commands/daily.md" ~/.claude/commands/daily.md
replace_placeholders ~/.claude/commands/daily.md
echo "  ✓ ~/.claude/commands/daily.md"

# 2. Worker instructions
cp "$SCRIPT_DIR/.claude/daily-worker.md" ~/.claude/daily-worker.md
replace_placeholders ~/.claude/daily-worker.md
echo "  ✓ ~/.claude/daily-worker.md"

# 3. Scripts
mkdir -p ~/bin
cp "$SCRIPT_DIR/bin/run-daily-report.sh" ~/bin/run-daily-report.sh
chmod +x ~/bin/run-daily-report.sh
echo "  ✓ ~/bin/run-daily-report.sh"

cp "$SCRIPT_DIR/bin/fetch-calendar.py" ~/bin/fetch-calendar.py
chmod +x ~/bin/fetch-calendar.py
echo "  ✓ ~/bin/fetch-calendar.py"

# 4. LaunchAgent (optional)
read -rp "LaunchAgent（毎日21:00自動実行）を設定しますか？ (y/N): " SETUP_LAUNCH
if [[ "$SETUP_LAUNCH" == "y" || "$SETUP_LAUNCH" == "Y" ]]; then
    PLIST_NAME="com.$(whoami).daily-report.plist"
    cp "$SCRIPT_DIR/launchagent/com.daily-report.plist.template" ~/Library/LaunchAgents/"$PLIST_NAME"
    replace_placeholders ~/Library/LaunchAgents/"$PLIST_NAME"
    launchctl load ~/Library/LaunchAgents/"$PLIST_NAME" 2>/dev/null || true
    echo "  ✓ ~/Library/LaunchAgents/$PLIST_NAME"
fi

echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "使い方:"
echo "  対話モード:  Claude Code で /daily を実行"
echo "  自動モード:  毎日21:00にLaunchAgentが実行（設定した場合）"
echo ""
echo "設定を変更したい場合:"
echo "  ~/.claude/daily-worker.md の「設定」セクションを直接編集してください"
