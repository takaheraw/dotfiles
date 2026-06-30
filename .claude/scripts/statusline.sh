#!/bin/bash
#
# Claude Code statusline。
# stdin にセッションデータの JSON が渡される。フィールド定義:
#   https://code.claude.com/docs/ja/statusline
#
# 表示: 🤖 モデル | 💰 当日トータル$ | 📊 コンテキスト使用率 | ⏳ レート制限
#   - 💰 は ccusage による「当日の全セッション合算」推定コスト（実請求とは異なる）。
#     ネイティブの cost.total_cost_usd は現在のセッション分のみのため使わない。
#   - context_window.used_percentage : 事前計算済みの使用率（窓サイズ 200K/1M を自動考慮）
#   - rate_limits.*              : claude.ai サブスクのみ、最初の API 応答後に出現

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude"
mkdir -p "$CACHE_DIR"
readonly CACHE_FILE="$CACHE_DIR/statusline_cost_cache"
readonly CACHE_TTL=60 # seconds

# ccusage で当日の合計コストを取得（外部依存。無ければ 0）
calculate_daily_cost() {
  command -v npx >/dev/null 2>&1 || { echo "0"; return; }

  local today today_hyphen
  today=$(date +%Y%m%d)          # ccusage 引数用
  today_hyphen=$(date +%Y-%m-%d) # JSON 内の日付形式

  local ccusage_output
  ccusage_output=$(npx -y ccusage@20.0.14 daily --json --since "$today" --until "$today" 2>/dev/null)

  if [ -z "$ccusage_output" ] || [ "$ccusage_output" = "[]" ]; then
    echo "0"
    return
  fi

  # ccusage の日次フィールドは period（旧 date）。agent 別に複数行あり得るため合算する。
  echo "$ccusage_output" | jq -r --arg d "$today_hyphen" '
    [.daily[] | select(.period == $d) | .totalCost] | add // 0
  ' 2>/dev/null || echo "0"
}

# 当日キャッシュが新しければ再利用、なければ再計算
get_cached_cost() {
  local today
  today=$(date +%Y%m%d)

  if [ -f "$CACHE_FILE" ]; then
    local cache_date cache_cost cache_age
    cache_date=$(head -1 "$CACHE_FILE" 2>/dev/null)
    cache_cost=$(tail -1 "$CACHE_FILE" 2>/dev/null)
    cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))

    if [ "$cache_date" = "$today" ] && [ "$cache_age" -le "$CACHE_TTL" ]; then
      echo "${cache_cost:-0}"
      return
    fi
  fi

  local cost
  cost=$(calculate_daily_cost)
  cost="${cost:-0}"

  printf '%s\n%s\n' "$today" "$cost" >"$CACHE_FILE"
  echo "$cost"
}

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

cost=$(get_cached_cost)
cost_fmt=$(printf '$%.2f' "$cost")

# レート制限は不在のことがある（API 利用時・初回応答前）。// empty で握りつぶす
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

limits=""
[ -n "$five_h" ] && limits=$(printf ' | ⏳ 5h %.0f%%' "$five_h")
[ -n "$week" ] && limits="$limits $(printf '7d %.0f%%' "$week")"

printf '🤖 %s | 💰 %s | 📊 %s%%%s\n' "$model" "$cost_fmt" "$pct" "$limits"
