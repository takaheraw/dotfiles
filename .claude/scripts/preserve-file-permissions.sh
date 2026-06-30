#!/bin/bash
set -uo pipefail

# デバッグログ
DEBUG_LOG="/tmp/claude_permissions_debug.log"

# 権限を保存するための一時ファイル
PERMISSIONS_CACHE="/tmp/claude_file_permissions.txt"

# 標準入力から JSON を読み込み
input_json=$(cat)

# Ensure input is always forwarded even on unexpected errors
trap 'echo "$input_json"' EXIT

# jq is required to parse JSON fields
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found; skipping permission preservation" >&2
  exit 0
fi

# JSON から必要な情報を抽出
if ! hook_type=$(echo "$input_json" | jq -r '.hook_event_name // ""'); then
  echo "Failed to parse hook_event_name from input" >&2
  exit 0
fi
if ! tool_name=$(echo "$input_json" | jq -r '.tool_name // ""'); then
  echo "Failed to parse tool_name from input" >&2
  exit 0
fi
if ! file_path=$(echo "$input_json" | jq -r '.tool_input.file_path // ""'); then
  echo "Failed to parse file_path from input" >&2
  exit 0
fi

# デバッグ情報を記録
echo "[$(date)] Hook: $hook_type, Tool: $tool_name, File: $file_path" >>"$DEBUG_LOG"

# ファイル操作系のツールのみ対象
case "$tool_name" in
Write | Edit) ;;
*)
  # 何もせずに通過
  trap - EXIT
  echo "$input_json"
  exit 0
  ;;
esac

# ファイルパスが空の場合は通過
if [ -z "$file_path" ]; then
  trap - EXIT
  echo "$input_json"
  exit 0
fi

if [ "$hook_type" = "PreToolUse" ]; then
  # ファイルが存在する場合、現在の権限を記録
  if [ -f "$file_path" ]; then
    # 権限を取得(8 進数形式)
    current_perms=$(stat -f "%OLp" "$file_path" 2>/dev/null || stat -c "%a" "$file_path" 2>/dev/null)
    if [ -n "$current_perms" ]; then
      # ファイルパスと権限を保存
      echo "${file_path}:${current_perms}" >>"$PERMISSIONS_CACHE"
      echo "Saved permissions for $file_path: $current_perms" >&2
      echo "[$(date)] PreToolUse: Saved $file_path with permissions $current_perms" >>"$DEBUG_LOG"
    fi
  fi

elif [ "$hook_type" = "PostToolUse" ]; then
  # 保存された権限があれば復元
  if [ -f "$PERMISSIONS_CACHE" ]; then
    # 該当ファイルの権限を検索
    saved_entry=$(grep "^${file_path}:" "$PERMISSIONS_CACHE" | tail -1)
    if [ -n "$saved_entry" ]; then
      saved_perms=$(echo "$saved_entry" | cut -d: -f2)
      if [ -n "$saved_perms" ] && [ -f "$file_path" ]; then
        if chmod "$saved_perms" "$file_path" 2>&1; then
          echo "Restored permissions for $file_path: $saved_perms" >&2
          echo "[$(date)] PostToolUse: Restored $file_path to permissions $saved_perms" >>"$DEBUG_LOG"

          # バックグラウンドで 3 秒待ってから再度権限を設定
          (
            sleep 3
            if chmod "$saved_perms" "$file_path" 2>&1; then
              echo "[$(date)] PostToolUse: Re-restored $file_path to permissions $saved_perms (delayed 3s)" >>"$DEBUG_LOG"
            else
              echo "[$(date)] PostToolUse: Failed to re-restore $file_path to $saved_perms (delayed 3s)" >>"$DEBUG_LOG"
            fi
          ) &

          # キャッシュから該当エントリを削除
          grep -v "^${file_path}:" "$PERMISSIONS_CACHE" >"${PERMISSIONS_CACHE}.tmp" || true
          mv "${PERMISSIONS_CACHE}.tmp" "$PERMISSIONS_CACHE" 2>/dev/null || true
        else
          echo "Failed to restore permissions for $file_path" >&2
        fi
      fi
    fi
  fi
fi

# trap EXIT handles forwarding input_json; clear it so we don't double-print
trap - EXIT
echo "$input_json"
