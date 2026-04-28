#!/usr/bin/env bash
###ANEW:20260428a

set -euo pipefail

FILE_DATETIME_STRING=$(date -u +"%Y%m%dT%H%M%SZ")

command -v uvx >/dev/null || { echo "✗ 需先安裝 uvx (uv)" >&2; exit 1; }
command -v git >/dev/null || { echo "✗ 需先安裝 git" >&2; exit 1; }

TARGET_DIR="$(pwd -P)"
SK_VERSION_DEFAULT="${SK_VERSION:-v0.8.1}"
GIT_USER_NAME_DEFAULT="$(git config --global user.name  2>/dev/null || true)"
GIT_USER_EMAIL_DEFAULT="$(git config --global user.email 2>/dev/null || true)"

backup_project_file() {
  local path="$1/$2"
  path=$(echo "$path" | sed -E 's#/+#/#g')
  [ -f "$path" ] || return 0
  cp -f "$path" "$path.$FILE_DATETIME_STRING.bak"
  echo "ℹ 已備份: $path.$FILE_DATETIME_STRING.bak"
}

ask_required_project() {
  local label="$1" reply
  while :; do
    read -rp "$label: " reply
    [[ "$reply" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]] && { printf '%s' "$reply"; return; }
    echo "  ✗ 只接受字母/數字/底線/連字號/句點,首字必須是字母、數字或底線" >&2
  done
}

ask_with_default() {
  local -n out=$1
  local label="$2" default="$3" reply
  if [[ -n "$default" ]]; then
    read -rp "$label ($default) 或輸入: " reply
    out="${reply:-$default}"
  else
    read -rp "$label (必填) 請輸入: " reply
    if [[ -z "$reply" ]]; then
      echo "✗ $label 必填,中止" >&2
      exit 1
    fi
    out="$reply"
  fi
}

echo "=== Spec-Kit project initializer ==="

SK_PROJECT=$(ask_required_project "Project 名稱(目錄名)")
ask_with_default SK_VERSION "Spec-Kit version" "$SK_VERSION_DEFAULT"
[[ "$SK_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo -e "✗ Spec-Kit version 格式需為 vX.Y.Z \n可用版本: https://github.com/github/spec-kit/releases" >&2
  exit 1
}
[[ "$(printf '%s\n%s\n' "v0.8.1" "$SK_VERSION" | sort -V | head -1)" == "v0.8.1" ]] || {
  echo -e "✗ Spec-Kit version 不可低於 v0.8.1 \n可用版本: https://github.com/github/spec-kit/releases" >&2
  exit 1
}

ask_with_default GIT_USER_NAME  "Git user.name"  "$GIT_USER_NAME_DEFAULT"
[[ "$GIT_USER_NAME" =~ ^[A-Za-z0-9_][A-Za-z0-9._\ -]*[A-Za-z0-9_]$ ]] || {
  echo "✗ Git user.name 格式不符,允許:字母/數字/底線/連字號/句點/空白;首尾必須字母/數字/底線" >&2
  exit 1
}

ask_with_default GIT_USER_EMAIL "Git user.email" "$GIT_USER_EMAIL_DEFAULT"
[[ "$GIT_USER_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || {
  echo "✗ Git user.email 格式不符,需為標準格式: 例如 user@example.com" >&2
  exit 1
}

if [ -f "$TARGET_DIR/$SK_PROJECT/.git" ] ; then
  echo "✗ '$SK_PROJECT' 是 git repo 但找不到本地 .git/config (可能為 worktree/submodule),不能在此設定 identity" >&2
  cat "$TARGET_DIR/$SK_PROJECT/.git" >&2
  exit 1
fi

cd "$TARGET_DIR"
if [[ "$GIT_USER_NAME_DEFAULT" != "$GIT_USER_NAME" ]] || [[ "$GIT_USER_EMAIL_DEFAULT" != "$GIT_USER_EMAIL" ]] ; then
  [ ! -d "$TARGET_DIR/$SK_PROJECT/" ] && mkdir -p "$SK_PROJECT"
  cd "$SK_PROJECT"
  if [ -d "$TARGET_DIR/$SK_PROJECT/.git" ] ; then
    git config --local --get user.name  >/dev/null 2>&1 || git config --local user.name  "$GIT_USER_NAME"
    GIT_USER_NAME_LOCAL="$(git config --local --get user.name)"
    [[ "$GIT_USER_NAME_LOCAL" != "$GIT_USER_NAME" ]] && echo "ℹ git local user.name='$GIT_USER_NAME_LOCAL' != '$GIT_USER_NAME'"

    git config --local --get user.email >/dev/null 2>&1 || git config --local user.email "$GIT_USER_EMAIL"
    GIT_USER_EMAIL_LOCAL="$(git config --local --get user.email)"
    [[ "$GIT_USER_EMAIL_LOCAL" != "$GIT_USER_EMAIL" ]] && echo "ℹ git local user.email='$GIT_USER_EMAIL_LOCAL' != '$GIT_USER_EMAIL'"
  else
    git init -q
    git config --local user.name  "$GIT_USER_NAME"
    git config --local user.email "$GIT_USER_EMAIL"
  fi
fi

cd "$TARGET_DIR"
if [ ! -d "$TARGET_DIR/$SK_PROJECT/" ] ; then
  uvx --from "git+https://github.com/github/spec-kit.git@${SK_VERSION}" \
    specify init $SK_PROJECT --integration claude
  echo "✅ '$SK_PROJECT' 初始化完成[父層目錄]($TARGET_DIR/$SK_PROJECT)"
  (
    cd "$TARGET_DIR/$SK_PROJECT"
    git add .specify .claude/skills/speckit* CLAUDE.md
    git diff --cached --quiet || git commit -m "Add Spec-Kit extensions and presets" --quiet
  )
  echo "✅ extensions / presets 已補入 git"
elif [ -d "$TARGET_DIR/$SK_PROJECT/.specify/" ] ; then
  {
    echo "✗ 已略過,'$SK_PROJECT' 之前已初始化"
    echo ""
    echo "ℹ 目前設定($SK_PROJECT/.specify/init-options.json):"
    cat "$TARGET_DIR/$SK_PROJECT/.specify/init-options.json"
    echo ""
    echo "ℹ 若要升級到 ${SK_VERSION},建議流程:"
    echo "  1. cd '$SK_PROJECT' && git checkout -b upgrade-speckit-${SK_VERSION}"
    echo "  2. uvx --from \"git+https://github.com/github/spec-kit.git@${SK_VERSION}\" \\"
    echo "       specify init --here --no-git --force --integration claude"
    echo "  3. git diff   # 檢視變更"
    echo "  4. 不滿意:git checkout HEAD -- <檔> 救回客製內容"
    echo "  5. 滿意:git add -A && git commit -m \"Upgrade Spec-Kit to ${SK_VERSION}\""
  } >&2
  exit 1
elif [ -d "$TARGET_DIR/$SK_PROJECT/.git/" ] ; then
  # SK_PROJECT 目錄存在,但未 specify init
  # --here 進入既有目錄;--no-git 不讓 spec-kit 重做 git init;
  # 不加 --force,讓檔案層級走 skip 分支(既有 CLAUDE.md 等不會被覆蓋)
  cd "$TARGET_DIR/$SK_PROJECT/"
  backup_project_file "$TARGET_DIR/$SK_PROJECT/" "CLAUDE.md"
  echo "y" | uvx --from "git+https://github.com/github/spec-kit.git@${SK_VERSION}" \
    specify init --here --no-git --integration claude
  echo "✅ '$SK_PROJECT' 初始化完成[專案目錄]($TARGET_DIR/$SK_PROJECT)"
  (
    cd "$TARGET_DIR/$SK_PROJECT"
    git add .specify .claude/skills/speckit* CLAUDE.md
    git diff --cached --quiet || git commit -m "Add Spec-Kit extensions and presets" --quiet
  )
  echo "✅ extensions / presets 已補入 git"
else # .specify/ 與 .git/ 都不存在時
  echo "ℹ '$SK_PROJECT' 尚未初始化!!! 是否使用 specify init --force"
  echo "⚠ --force 會覆蓋目錄內既有檔且無法復原,請先[備份]重要內容"
  read -rp "是否已[備份]重要內容,並開始 specify init --force (y/N): " SK_FORCE
  if [[ "$SK_FORCE" =~ ^[Yy]$ ]] ; then
    backup_project_file "$TARGET_DIR/$SK_PROJECT/" "CLAUDE.md"
    uvx --from "git+https://github.com/github/spec-kit.git@${SK_VERSION}" \
      specify init $SK_PROJECT --force --integration claude
    echo "ℹ '$SK_PROJECT' 初始化完成[父層強制]($TARGET_DIR/$SK_PROJECT)"
  else
    echo "✗ 已略過,'$SK_PROJECT' 未變更" >&2
  fi
fi
