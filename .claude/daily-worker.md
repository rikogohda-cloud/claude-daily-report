# 日報ワーカー（Sonnet subagent用）

このファイルはSonnet subagentが読んで実行する作業指示書。
データ収集→分析→レポート生成まで行い、最終出力を返す。

## 設定（ユーザーごとにカスタマイズ）

| 項目 | 値 |
|------|-----|
| ユーザー名 | Riko Gohda |
| Slack User ID | U07E74J2GEM |
| Slack Handle | @riko.gohda |
| Slack Crawler DB |  |
| 除外チャンネル（times系） | times_riko |
| 議事録 Notion DB ID | 30d93c7ce32d8014a26ff8583dfadc9e |
| 振り返りトーン | strict |

### アクティビティ分類カスタマイズ

以下はデフォルトの分類テーブル。自分の業務に合わせて書き換えること:

| カテゴリ | 判定基準 | カウント |
|---------|---------|---------|
| 意思決定 | 方針決定、承認/却下、差し戻し、判断 | YES |
| レビュー/FB | メンバーの作業確認、FB、ナレッジ共有 | YES |
| 問題解決 | 障害対応、エスカレーション | YES |
| メンバー育成 | チームメンバーへの指導、考え方の説明 | YES |
| 調整・連絡 | MTG調整、要件確認、情報共有のファシリ | 3件以上なら |
| 調査・リサーチ | Notionでの調査、分析 | YES |
| AI活用・自動化 | Claude Code/Codexでの開発、スクリプト作成 | YES |
| ルーティン | 定型業務、承認フロー | まとめて件数 |
| Bot/自動通知 | 自動投稿、WFログ | SKIP |

### 除外対象カスタマイズ

以下のメッセージはスレッド文脈取得・レポートから除外する。自分の環境に合わせて書き換え:

- times系チャンネルのbot通知
- ワークフローのボタン操作のみ
- Bot自動投稿（WFログ等）

---

## Step 0: ツールロード

最初にToolSearchで以下を検索してツールをロードする（並列実行）:
- `"slack"` → conversations_search_messages, conversations_replies 等
- `"notion"` → notion-search, notion-fetch 等
- `"select:mcp__notion__notion-query-data-sources"` → 議事録DBクエリ用

---

## Step 1: 並列データ収集

以下を**すべて並列**で実行する（議事録DB未設定の場合は1-Lをスキップ）:

### 1-A. Slack: 今日ユーザーが送信したメッセージ（DM含む）
```
conversations_search_messages: filter_users_from=@riko.gohda, filter_date_during=Today, limit=25
```
→ チャンネル投稿 + DM送信の両方を含む。DM分は詳細ログの「DM」セクションに振り分ける。

### 1-D. Slack: メンション（直近3日・未返信チェック兼用）
```
conversations_search_messages: search_query=@riko.gohda, filter_date_after=<3日前の日付>, limit=25
```
→ 日付で「今日」と「昨日以前」を分離して使用:
  - 今日分 → 当日のメンション一覧
  - 全期間 → 各スレッドを conversations_replies で確認し、ユーザーが最後に発言した後に質問・依頼が来ていないかチェック

### 1-E. SQLite: 過去14日baseline
```bash
sqlite3  "
SELECT date(substr(m.ts,1,10),'unixepoch','localtime') as day,
  count(*) as msg_count,
  count(DISTINCT m.channel_id) as channel_count
FROM messages m
JOIN channels c ON m.channel_id = c.channel_id
WHERE m.user_id = 'U07E74J2GEM'
  AND c.name != 'times_riko'
  AND date(substr(m.ts,1,10),'unixepoch','localtime') >= date('now','-14 days','localtime')
GROUP BY day ORDER BY day DESC;
"
```

### 1-F. SQLite: 今日の時間帯別分布
```bash
sqlite3  "
SELECT strftime('%H',substr(ts,1,10),'unixepoch','localtime') as hour,
  count(*) as cnt
FROM messages m
JOIN channels c ON m.channel_id = c.channel_id
WHERE m.user_id = 'U07E74J2GEM'
  AND c.name != 'times_riko'
  AND date(substr(m.ts,1,10),'unixepoch','localtime') = date('now','localtime')
GROUP BY hour ORDER BY hour;
"
```
注意: crawlerは当日データが不完全な場合がある。Slack MCPの検索結果のタイムスタンプも時間推定の補助に使用すること。

### 1-G. Google Calendar: 今日の予定
```bash
python3 ~/bin/fetch-calendar.py
```
→ Calendar APIが使えない場合は空配列が返る（graceful fallback）。その場合は「カレンダー情報: 未連携」と表示。

### 1-H. Notion: 当日作成・更新ページ（議事録以外）
ToolSearchで `"notion"` を検索してツールをロード後、以下を実行:
```
notion-search: query="", filter: { property: "object", value: "page" }, sort: { direction: "descending", timestamp: "last_edited_time" }
```
→ 直近更新ページを取得し、対象日に作成・更新されたものを抽出。
→ **議事録DB（ID: `30d93c7ce32d8014a26ff8583dfadc9e`）配下のページは除外**（1-Lで取得するため）。議事録DB未設定の場合は除外なし。
→ 残りのページについて `notion-fetch` で内容を読む（タイトルだけでは何を作ったか分からないため）。
→ リサーチレポート、分析ドキュメント等、ユーザーが作成した知的アウトプットを特定する。
→ 各ページの「何についてのドキュメントか」「主要な結論・発見」を要約する。

### 1-I. Codex: 当日セッションログ
```bash
TODAY=$(date +%d)
MONTH=$(date +%m)
SESSION_DIR="$HOME/.codex/sessions/$(date +%Y)/$MONTH/$TODAY"
if [ -d "$SESSION_DIR" ]; then
  for f in "$SESSION_DIR"/*.jsonl; do
    python3 -c "
import json, sys
for line in open('$f'):
    entry = json.loads(line)
    if entry.get('type') == 'session_meta':
        print('SESSION:', entry['payload'].get('id','')[:8], entry['payload'].get('timestamp',''))
    elif entry.get('type') == 'response_item':
        p = entry.get('payload', {})
        if p.get('role') == 'user':
            for c in p.get('content', []):
                t = c.get('text', '')
                if not t.startswith('<') and len(t) > 20:
                    print('  USER:', t[:200])
                    break
"
  done
else
  echo "No Codex sessions today"
fi
```
→ Codexで行った作業の概要を抽出。セッションがない日はスキップ。

### 1-K. Claude Code: 当日セッションログ
```bash
python3 -c "
import json, glob, os
from datetime import datetime, timezone, timedelta
JST = timezone(timedelta(hours=9))
target = os.environ.get('TARGET_DATE', datetime.now(JST).strftime('%Y-%m-%d'))
start = datetime.strptime(target, '%Y-%m-%d').replace(hour=0, minute=0, second=0, tzinfo=JST).timestamp() * 1000
end = start + 86400000
seen = set()
sessions = []
with open(os.path.expanduser('~/.claude/history.jsonl')) as f:
    for line in f:
        e = json.loads(line)
        ts = e.get('timestamp', 0)
        sid = e.get('sessionId', '')
        if start <= ts < end and sid not in seen:
            seen.add(sid)
            dt = datetime.fromtimestamp(ts/1000, tz=JST)
            display = e.get('display', '')[:200]
            sessions.append((sid, dt, display))
            print(f'SESSION: {sid[:8]} TIME: {dt.strftime(\"%H:%M\")} PROMPT: {display}')
if not sessions:
    print('No Claude Code sessions')
else:
    # Extract first substantive user message from each session
    for sid, dt, _ in sessions:
        for proj_dir in glob.glob(os.path.expanduser('~/.claude/projects/*/')):
            fpath = os.path.join(proj_dir, f'{sid}.jsonl')
            if os.path.exists(fpath):
                msgs = []
                with open(fpath) as sf:
                    for sline in sf:
                        se = json.loads(sline)
                        if se.get('type') == 'user':
                            msg = se.get('message', '')
                            content = ''
                            if isinstance(msg, dict):
                                content = msg.get('content', '')
                                if isinstance(content, list):
                                    for c in content:
                                        if isinstance(c, dict) and c.get('type') == 'text':
                                            content = c.get('text', '')
                                            break
                            elif isinstance(msg, str):
                                content = msg
                            if content and len(content) > 20 and not content.startswith('<'):
                                msgs.append(content[:200])
                if msgs:
                    print(f'  DETAIL[{sid[:8]}]: {\" | \".join(msgs[:5])}')
                break
"
```
→ Claude Codeで行った作業の概要を抽出。セッションがない日はスキップ。

### 1-L. Notion: 当日の議事録
議事録DB（ID: `30d93c7ce32d8014a26ff8583dfadc9e`）を `notion-query-data-sources` でクエリし、当日作成された行を取得する。
```
notion-query-data-sources: dataSourceId="30d93c7ce32d8014a26ff8583dfadc9e"
```
→ 当日分のページをフィルタして抽出。
→ 取得した各ページを `notion-fetch` で内容を読む。
→ 各MTGについて以下を抽出:
  - MTG名（タイトル）
  - 決定事項
  - アクションアイテム（担当者・期限）
  - 主要な議論ポイント
→ カレンダー(1-G)のMTG一覧と突合し、「議事録あり/なし」を明示する。

**議事録DB未設定（`30d93c7ce32d8014a26ff8583dfadc9e` が空）の場合はこのステップをスキップ。**

---

## Step 2: スレッド文脈取得

Step 1で見つかったスレッドのうち、substantiveなもの**上位5件**について `conversations_replies` で全文脈を取得する。

**スレッドID dedup:** 1-Aと1-Dで同一スレッドがヒットした場合、1回だけfetchする。channel_id + thread_ts の組み合わせで重複判定。

**除外対象:** 設定セクションの「除外対象カスタマイズ」に記載されたパターンに該当するもの。

---

## Step 3: 分析・分類

### アクティビティ分類

設定セクションの「アクティビティ分類カスタマイズ」テーブルに従って分類する。

### インパクト評価

| Level | 基準 |
|-------|------|
| :red_circle: 高 | 大きな意思決定、インシデント、ポリシー変更、重大リスク |
| :large_orange_diamond: 中 | 通常の業務判断、運用改善、プロセス変更 |
| :white_circle: 低 | 日常的な確認、軽微な調整 |

### 時間推定ヒューリスティック

1. カレンダーイベント → そのまま使用
2. **議事録あり MTG → MTG時間 + 議事録作成時間（+15min推定）**
3. Slackメッセージ群:
   - 同一スレッド5分以内 → 1つの作業ブロック
   - ブロック所要時間 = max(10分, メッセージ数×5分, ブロック内時間幅)
   - 30分以上のギャップ → 別の活動
4. **Notionページ → created_time〜last_edited_time の幅を作業時間の推定に使用**（1-Hで取得したページ）
5. カテゴリ別の配分 → 各ブロックの属するチャンネル・ソースからカテゴリを推定
6. SQLiteの時間帯別データ + Slack MCPのタイムスタンプ = 稼働開始/終了時刻

### 振り返りポイント抽出

振り返りトーン（設定セクション参照）に従い、以下の3観点で2-4個:
- :warning: ヒヤリハット — 「もっと早く気づけた」「仕組みで防げた」
- :thought_balloon: プロセス改善 — 手動→自動化、繰り返し→テンプレ化
- :muscle: 好事例 — 早期判断、効果的なエスカレーション

### 優先度サジェスト

未返信メンション + 当日発生課題 + カレンダーの明日の予定 + **議事録のアクションアイテム（ユーザー担当分）**から:
1. 事業インパクト（金額、顧客影響、コンプラリスク）
2. ブロッカー度（他チームを止めているか）
3. 期限の近さ

---

## Step 4: レポート生成

以下の6セクション構成で日報テキストを生成する。装飾はSlackのmrkdwn形式。

### A. スコアカード
```
:bar_chart: 日報 YYYY-MM-DD（曜日）

稼働: HH:MM - HH:MM（推定アクティブ X.Xh / MTG X.Xh）
意思決定 X件 / レビュー X件 / 問題解決 X件 / 育成 X件 / 調査 X件
ルーティン: 定型業務 X件
MTG議事録: X/X件（議事録あり/カレンダーMTG数）
Notion: X件作成 / Codex: Xセッション / Claude Code: Xセッション
```

### B. 主要アウトプット（インパクト順）
チャンネル別ではなく**インパクト別**に並べる。:red_circle: → :large_orange_diamond: → :white_circle: の順。
**Notionで作成したドキュメント（リサーチレポート、議事録、分析等）もアウトプットとして含める。** Slackでのやり取りだけでなく、ドキュメントとして残した知的成果物を漏らさない。
```
*:clipboard: 主要アウトプット*

:red_circle: 重大な意思決定・リスク対応
- 具体的な案件名: 何をしたか → 結果・判断
  - 補足（なぜ起きた、仕組み化案等あれば）

:large_orange_diamond: 業務判断
- 具体的な案件名: 判断内容

:large_orange_diamond: MTG決定事項
- [議事録] MTG名: 決定事項の要約、アクションアイテム

:large_orange_diamond: ドキュメント作成
- [Notion] ドキュメント名: 主要な結論・発見の要約

:white_circle: 調整・連絡
- 軽微なもの
```
各項目は1行で簡潔に。補足がある場合のみインデントで追記。

### C. 時間配分
```
*:clock3: 時間配分*
カテゴリA  ████████░░ X.Xh (XX%)
カテゴリB  ██████░░░░ X.Xh (XX%)
...
先週平均比: カテゴリA +XX%, カテゴリB -XX%
```
プログレスバーは全角ブロック文字（█ と ░）で10文字幅。先週平均比はSQLiteのbaseline（1-E）から算出。

### D. 振り返り
```
*:bulb: 振り返り*
:warning: ヒヤリハット — 具体的かつactionableに
:thought_balloon: プロセス改善 — 具体的かつactionableに
:muscle: Good: 好事例
```
汎用的な振り返り（「忙しかった」「もっと効率化したい」等）は禁止。具体的な案件名・数値に言及すること。

### E. 明日の優先度（事業インパクト順）
```
*:dart: 明日やること（事業インパクト順）*
1. :red_circle: タスク名 — 理由（金額、ブロッカー度）
2. :red_circle: タスク名 — 理由
3. :large_orange_diamond: タスク名 — 理由
4. :large_orange_diamond: タスク名 — 理由
5. :white_circle: タスク名 — 理由
```
最大7件。未返信メンション + 当日発生した未完了課題 + **議事録のアクションアイテム（ユーザー担当分）**から自動抽出。

### F. 詳細ログ（スレッド返信用）
```
*:file_folder: 詳細ログ*

_業務カテゴリ1_
- [#channel_name] 要約

_業務カテゴリ2_
- [#channel_name] 要約

_DM_
- @相手名: 要約

_議事録_
- [MTG名] 決定事項 / AI要約

_Notionアウトプット_
- ページタイトル: 内容概要

_Codex作業_
- 作業概要

_Claude Code作業_
- セッション概要: 何を作成・修正したか
```

### 生成ルール
- 日報の口調はニュートラル（敬語不要）
- 機密情報はSlack社内チャンネルなのでそのまま記載OK
- Slackの1メッセージ4000文字制限に注意。オーバーする場合はセクションを分割
- 量が多い場合は重要度の高いものを優先し、最大15件程度に絞る

---

## 最終出力フォーマット

以下の2ブロックをテキストで返す（マーカー行で区切る）:

```
===MAIN===
（セクションA-E、Slack mrkdwn形式）

===THREAD===
（セクションF、Slack mrkdwn形式）
```

### トークン最適化ルール
**目標: 出力を30,000トークン以内に抑える**

1. **絵文字は最小限**: ■●○・!+✓のみ使用。:bar_chart: :clipboard: などの装飾絵文字は不要
2. **簡潔な表現**:
   - 「〜を確認し、〜を検討し、〜を実施」→「確認・検討・実施」
   - 「背景:」「補足:」などのラベルは必要最小限
3. **詳細ログは各カテゴリ最大3件**: 重要度の高いものを優先
4. **1項目あたり最大100文字**: 冗長な説明は削減

## 注意事項
- Botとのやり取りのみ（WFボタン操作等）は含めない。人との実質的なやり取りのみ
- ルーティン業務は個別に書かず「XX件対応」のようにまとめる
- 振り返りは必ず具体的な案件名・数値に言及し、actionableにする
