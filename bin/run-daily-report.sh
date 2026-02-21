#!/bin/bash
# 日報自動生成スクリプト
# LaunchAgentから毎日指定時刻に実行される
# Claude CLIの/dailyコマンドを非対話モードで実行し、日報を生成・投稿する

set -euo pipefail

LOG_FILE="$HOME/Library/Logs/daily-report.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Starting daily report generation..." >> "$LOG_FILE"

# Claude CLIのパス
CLAUDE_CLI="$HOME/.local/bin/claude"

if [ ! -x "$CLAUDE_CLI" ]; then
    echo "[$TIMESTAMP] ERROR: Claude CLI not found at $CLAUDE_CLI" >> "$LOG_FILE"
    exit 1
fi

# 日報生成プロンプト（分析版）
DAILY_PROMPT="本日の分析型日報を生成して投稿先チャンネルに投稿してください。/daily コマンドのStep 1-4に従って実行してください。投稿前確認はスキップして直接投稿してOKです。メイン投稿（スコアカード〜明日の優先度）と、スレッド返信（詳細ログ）の2段階で投稿すること。"

$CLAUDE_CLI -p "$DAILY_PROMPT" \
    --allowedTools "mcp__slack__conversations_search_messages,mcp__slack__conversations_add_message,mcp__slack__conversations_history,mcp__slack__conversations_replies,mcp__slack__channels_list,mcp__notion__notion-fetch,mcp__notion__notion-search,mcp__notion__notion-query-data-sources,Bash" \
    >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$TIMESTAMP] Daily report completed successfully." >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] Daily report failed with exit code $EXIT_CODE." >> "$LOG_FILE"
fi
