#!/usr/bin/env bash
set -euo pipefail

# Korean Pronunciation App → Netlify デプロイ
# 初回実行時に新規Netlifyサイトを作成し、site_idを .netlify-site-id に保存する。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/app"
SITE_ID_FILE="$SCRIPT_DIR/.netlify-site-id"
TOKEN_FILE="$HOME/.netlify-deploy-token"
SITE_NAME_HINT="korean-pronunciation-app"

if [[ ! -f "$TOKEN_FILE" ]]; then
  cat <<EOF
Netlifyトークンが未設定です。

1. https://app.netlify.com/user/applications#personal-access-tokens
   でPersonal Access Tokenを発行
2. 以下を実行:

   echo 'YOUR_TOKEN' > "$TOKEN_FILE" && chmod 600 "$TOKEN_FILE"

3. 再度 ./deploy.sh を実行
EOF
  exit 1
fi

TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"

# 初回: 新規サイト作成
if [[ ! -f "$SITE_ID_FILE" ]]; then
  echo "[初回] Netlifyに新規サイトを作成中..."
  CREATE_RESPONSE=$(curl -sS -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"name\":\"$SITE_NAME_HINT\"}" \
    "https://api.netlify.com/api/v1/sites")

  NEW_SITE_ID=$(printf '%s' "$CREATE_RESPONSE" | sed -n 's/.*"site_id":"\([^"]*\)".*/\1/p' | head -1)
  if [[ -z "$NEW_SITE_ID" ]]; then
    # "id" フィールドも試す
    NEW_SITE_ID=$(printf '%s' "$CREATE_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
  fi
  NEW_URL=$(printf '%s' "$CREATE_RESPONSE" | sed -n 's/.*"ssl_url":"\([^"]*\)".*/\1/p' | head -1)
  if [[ -z "$NEW_URL" ]]; then
    NEW_URL=$(printf '%s' "$CREATE_RESPONSE" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p' | head -1)
  fi

  if [[ -z "$NEW_SITE_ID" ]]; then
    echo "サイト作成失敗。レスポンス:"
    printf '%s\n' "$CREATE_RESPONSE"
    exit 1
  fi

  echo "$NEW_SITE_ID" > "$SITE_ID_FILE"
  echo "      site_id: $NEW_SITE_ID"
  echo "      URL:     $NEW_URL"
fi

SITE_ID="$(tr -d '[:space:]' < "$SITE_ID_FILE")"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
ZIP="$TMPDIR/deploy.zip"

echo "[1/3] $SRC_DIR をzip化..."
(cd "$SRC_DIR" && zip -r -q "$ZIP" .)
echo "      サイズ: $(du -h "$ZIP" | cut -f1)"

echo "[2/3] Netlifyへアップロード..."
RESPONSE=$(curl -sS -X POST \
  -H "Content-Type: application/zip" \
  -H "Authorization: Bearer $TOKEN" \
  --data-binary "@$ZIP" \
  "https://api.netlify.com/api/v1/sites/$SITE_ID/deploys")

DEPLOY_ID=$(printf '%s' "$RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
STATE=$(printf '%s' "$RESPONSE" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p' | head -1)

if [[ -z "$DEPLOY_ID" ]]; then
  echo "デプロイ失敗。レスポンス:"
  printf '%s\n' "$RESPONSE"
  exit 1
fi

echo "      deploy_id: $DEPLOY_ID (state: $STATE)"
echo "[3/3] 公開処理を待機..."

SITE_URL=""
for i in $(seq 1 30); do
  sleep 2
  DEPLOY_INFO=$(curl -sS -H "Authorization: Bearer $TOKEN" \
    "https://api.netlify.com/api/v1/sites/$SITE_ID/deploys/$DEPLOY_ID")
  STATUS=$(printf '%s' "$DEPLOY_INFO" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p' | head -1)
  if [[ -z "$SITE_URL" ]]; then
    SITE_URL=$(printf '%s' "$DEPLOY_INFO" | sed -n 's/.*"ssl_url":"\([^"]*\)".*/\1/p' | head -1)
  fi
  if [[ "$STATUS" == "ready" ]]; then
    echo "      完了: $SITE_URL"
    exit 0
  fi
  if [[ "$STATUS" == "error" ]]; then
    echo "      エラー状態になりました"
    exit 1
  fi
done

echo "      処理中（まだ ready になっていません）。数分後に Netlify を確認してください。"
echo "      URL: $SITE_URL"
