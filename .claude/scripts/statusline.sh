#!/bin/bash
#
# Claude Code statusline — ネイティブ JSON フィールドのみで構成（外部依存なし）。
# stdin にセッションデータの JSON が渡される。フィールド定義:
#   https://code.claude.com/docs/ja/statusline
#
# 表示: 🤖 モデル | 💰 セッション推定$ | 📊 コンテキスト使用率 | ⏳ レート制限
#   - cost.total_cost_usd        : このセッションのクライアント側推定コスト（実請求とは異なる）
#   - context_window.used_percentage : 事前計算済みの使用率（窓サイズ 200K/1M を自動考慮）
#   - rate_limits.*              : claude.ai サブスクのみ、最初の API 応答後に出現

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# レート制限は不在のことがある（API 利用時・初回応答前）。// empty で握りつぶす
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

cost_fmt=$(printf '$%.2f' "$cost")

limits=""
[ -n "$five_h" ] && limits=$(printf ' | ⏳ 5h %.0f%%' "$five_h")
[ -n "$week" ] && limits="$limits $(printf '7d %.0f%%' "$week")"

printf '🤖 %s | 💰 %s | 📊 %s%%%s\n' "$model" "$cost_fmt" "$pct" "$limits"
