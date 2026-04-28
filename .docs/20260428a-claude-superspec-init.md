# 20260428a — claude-superspec-init.sh 設計筆記

**會話日期**:2026-04-27 ~ 2026-04-28
**腳本路徑**:`./claude-superspec-init.sh`
**目的**:把 `uvx --from git+https://github.com/github/spec-kit.git@<ver> specify init <project> --integration claude` 包成互動式腳本,解決 spec-kit 原生流程的痛點。

---

## 起源:為什麼要包這支腳本?

### 比對 v0.7.5(`spec-kit-docker-nodejs/`) vs v0.8.1(`test/`)

從 `init-options.json` 與 manifest 確認版號差異後,主要實質差別:

1. **指令命名規則**:`/speckit.X`(點)→ `/speckit-X`(連字號) — 大量 SKILL.md 與 templates 的純文字替換。
2. **`.specify/scripts/bash/common.sh`**:新增約 270 行
   - `read_feature_json_feature_directory()`:set -e 安全的 feature.json 解析(jq → python3 → grep/sed 三層 fallback)
   - `feature_json_matches_feature_dir()`:讓 `feature.json` 釘住目錄能繞過 git branch 命名檢查
   - `resolve_template_content()`:四層 template composition(overrides / presets / extensions / core),支援 `replace`/`prepend`/`append`/`wrap` 策略
3. **`.specify/scripts/bash/setup-plan.sh`**:`feature.json` 釘住目錄就跳過 branch 命名驗證
4. **`.specify/scripts/bash/create-new-feature.sh`**:trim 從 `xargs` 改 `sed -E`(避免特殊字元解讀)
5. **PowerShell 4 個檔**:純 CRLF → LF 換行符切換,無內容變化

### 關鍵痛點:`specify init` 後檔案沒 commit

從 spec-kit v0.8.1 原始碼 `init_git_repo()` (lines 736-768) 確認:

```python
subprocess.run(["git", "init"], check=True, ...)
subprocess.run(["git", "add", "."], check=True, ...)
subprocess.run(["git", "commit", "-m", "Initial commit from Specify template"], check=True, ...)
```

**兩個獨立問題疊加**:
1. **commit 失敗**:沒設 git user.name/email → `git commit` 失敗 → spec-kit **不 abort,只 log 錯誤繼續走**,留下 staged 檔。
2. **設計如此**:即使 commit 成功,**git extension 的檔(`.claude/skills/speckit-git-*`、`.specify/extensions/`)是在 `init_git_repo()` 完成之後才安裝的**,一定 untracked。

**修復方向**:腳本要先設好 per-repo identity、處理多種既有目錄狀態、補 follow-up commit 把 extensions 納入版控。

---

## 設計決策摘要

### 1. 互動輸入 + 環境預設值

| 變數 | 預設值來源 | 驗證 |
|---|---|---|
| `SK_PROJECT` | 必填 | regex `^[A-Za-z0-9_][A-Za-z0-9._-]*$`(首字限字母/數字/底線,後續加 `.` `-`) |
| `SK_VERSION` | env `SK_VERSION` 或 `v0.8.1` | regex `^v[0-9]+\.[0-9]+\.[0-9]+$` + `sort -V` 比對最小版 |
| `GIT_USER_NAME` | `git config --global user.name` | regex `^[A-Za-z0-9_][A-Za-z0-9._\ -]*[A-Za-z0-9_]$`(允許空白,首尾必字母/數字/底線) |
| `GIT_USER_EMAIL` | `git config --global user.email` | 標準 email regex |

**`ask_with_default` 函式**:用 bash `local -n` nameref 寫回變數,空值且無預設時直接 `exit 1`(不能用 `$(...)` command substitution,因 `exit` 在 subshell 不會中止父 script)。

### 2. spec-kit 版本驗證

最小版鎖在 `v0.8.1`(寫死,使用者選擇不抽常數):

```bash
[[ "$(printf '%s\n%s\n' "v0.8.1" "$SK_VERSION" | sort -V | head -1)" == "v0.8.1" ]] || exit 1
```

`sort -V` 是 version-aware sort:`v0.7.5 < v0.8.1 < v0.9.0 < v0.10.0 < v0.12.1 < v1.0.0`(理解 12 > 9,非字串比較)。Linux/macOS/busybox 皆支援。

GitHub spec-kit releases tag 格式經實測**全部嚴格 `vMAJOR.MINOR.PATCH`**,無 pre-release 後綴、無分支名,所以 strict regex 合適。

### 3. Worktree/submodule 偵測 + 拒絕

`.git` 在 worktree 與 submodule(git 1.7.8+)都是**檔案**(內含 `gitdir: <path>`),內容形式一致。腳本前置檢查:

```bash
if [ -f "$TARGET_DIR/$SK_PROJECT/.git" ] ; then
  echo "✗ '...' 是 git repo 但找不到本地 .git/config (可能為 worktree/submodule),不能在此設定 identity" >&2
  cat "$TARGET_DIR/$SK_PROJECT/.git" >&2  # 印 gitdir: 指針讓使用者知道指到哪
  exit 1
fi
```

`cat .git` 印 `gitdir: <主 repo>/.git/worktrees/<n>` 或 `<parent>/.git/modules/<n>`,使用者一眼分辨。

### 4. Identity 設定區塊

```bash
if [[ "$GIT_USER_NAME_DEFAULT" != "$GIT_USER_NAME" ]] || [[ "$GIT_USER_EMAIL_DEFAULT" != "$GIT_USER_EMAIL" ]] ; then
  ...
fi
```

**進入條件:使用者改了 identity 預設值**(才需要釘 per-repo)。沿用 default 時跳過,讓 spec-kit 自己用全域 identity。

內部分兩支:
- **`.git/` 已存在**:用 `git config --local --get user.name` 條件式設定(local 沒設才填),並警告 mismatch。**注意必須加 `--local`**,否則 `git config --get` 會走 system → global → local → worktree 全部 scope,有全域時永遠不會進 `||` 分支。
- **`.git/` 不存在**:`git init -q` + `git config --local user.name/email` 寫入。

### 5. 主邏輯四象限 + force fallback

進入順序(L100-153):

| 條件 | 走的分支 | 行為 |
|---|---|---|
| 目錄不存在 | `if [ ! -d ]` | spec-kit 自動 `git init + add + commit`,然後 follow-up commit 補 extensions |
| 已有 `.specify/` | `elif` | 印升級提示 + cat init-options.json + `exit 1` |
| 已有 `.git/`(dir) | `elif` | spec-kit `--here --no-git` + `echo y` 自動回應 prompt + follow-up commit |
| 都不存在 | `else` | 詢問 `--force`,確認後 spec-kit `--force --integration claude` |

**Worktree 案例(`.git` 是 file)**:在 L74 已被 hard fail 攔下,進不來這個 chain,L99-101 worktree elif 已移除避免 dead code。

### 6. spec-kit `--here` vs `--force` 的副作用

從原始碼確認:
- **`--force`**:跳過確認 + **per-file 覆寫既有檔**(包括 CLAUDE.md)
- **`--here` 不加 `--force`**:用 `typer.confirm()` 互動詢問;`force=False` 時 per-file **skip 保護既有檔**

`--here --no-git --integration claude` + `echo y |` 自動 confirm 是「保護既有 CLAUDE.md」的最佳組合。

### 7. CLAUDE.md 備份(force / `--here --no-git` 兩條路徑)

```bash
backup_project_file() {
  local path="$1/$2"
  path=$(echo "$path" | sed -E 's#/+#/#g')   # normalize 多斜線
  [ -f "$path" ] || return 0                 # silent skip
  cp -f "$path" "$path.$FILE_DATETIME_STRING.bak"
  echo "ℹ 已備份: $path.$FILE_DATETIME_STRING.bak"
}
```

`FILE_DATETIME_STRING=$(date -u +"%Y%m%dT%H%M%SZ")` — UTC 時間戳 + `Z` 後綴(ISO 8601),避免跨時區誤讀。同一支腳本同一次執行的所有備份共用同一時間戳。

### 8. Follow-up commit:把 extensions 納入版控

```bash
(
  cd "$TARGET_DIR/$SK_PROJECT"
  git add .specify .claude/skills/speckit* CLAUDE.md
  git diff --cached --quiet || git commit -m "Add Spec-Kit extensions and presets" --quiet
)
```

`git diff --cached --quiet` 守護:沒實質變更就跳過 commit,避免 `set -e` 撞 "nothing to commit" 中止。

---

## 升級路徑(spec-kit 沒有 upgrade 指令)

從 v0.8.1 原始碼 grep:**沒有專屬 upgrade**。`specify self upgrade` 是 stub(只印 guidance);`specify integration upgrade` 根本不存在(雖然錯誤訊息提到要跑這條)。

**官方唯一升級方式**:`specify init --here --force` 用新版號重跑。

| 自動保留(即使 `--force`) | 被覆寫(`--force`) |
|---|---|
| `.specify/memory/constitution.md` | `.claude/skills/speckit-*/SKILL.md` |
| `.vscode/settings.json`(deep merge) | `.specify/scripts/bash/*.sh` |
| | `.specify/templates/*.md` |
| | `.specify/integrations/*.manifest.json` |
| | `CLAUDE.md`(若 `--force` 對 shared infra 生效) |

腳本 L110-125 elif 分支不自動跑升級,改提示使用者 5 步流程:

```
1. cd '$SK_PROJECT' && git checkout -b upgrade-speckit-${SK_VERSION}
2. uvx ... specify init --here --no-git --force --integration claude
3. git diff
4. 不滿意:git checkout HEAD -- <檔> 救回客製內容
5. 滿意:git add -A && git commit -m "Upgrade Spec-Kit to ${SK_VERSION}"
```

把「無痛升級」的責任交給 git workflow,而非依賴 spec-kit preservation 邏輯。

---

## 過程中踩到的 bug 與教訓

### 🔴 backtick command substitution(踩兩次)

第一次:
```bash
echo "⚠ ... 請先`備份`重要內容"
```
雙引號內反引號是 command substitution,bash 嘗試執行 `備份` 指令(找不到)→ 字串裡這段消失 + stderr 噴錯。修法:單引號、全形括號或 `[備份]`。

第二次(L102 早期版本):
```bash
echo "...\n`cat .specify/init-options.json`:" >&2
```
反引號 + 相對路徑兩錯疊一起:
- 反引號被當 command substitution 執行
- cwd 是 `$TARGET_DIR` 不是 `$SK_PROJECT`,`.specify/init-options.json` 在 cwd 找不到 → cat 失敗 + stderr 噪音

### 🔴 `[0-9]+*` 非法 quantifier 組合

POSIX ERE 不允許 `+` 後接 `*`。glibc 寬恕(退化成 `+`),但 BSD/macOS 較嚴的 regex 引擎可能報錯,讓 `[[ =~ ]]` 在 set -e 下中止。修法:單一 `+`。

### 🔴 if/else 分支顛倒(critical)

```bash
if [ ! -d "$SK_PROJECT/.git" ] ; then
  git config --local --get user.name ...   # 但這需要在 repo 內!
  ...
else
  git init -q
  ...
fi
```

`! -d .git` 為 true 表示「沒 repo」,但裡面卻在跑只有 repo 內才能跑的 `git config --local`。應反過來。

### 🔴 `local path "$1/$2"` 語法錯

```bash
local path "$1/$2"      # ❌ 不是 assignment
local path="$1/$2"      # ✅ 注意 = 兩側不能有空白
```

第一種寫法 bash 把 `path` 和 `$1/$2`(展開後含 `/`)當「兩個變數名」宣告,變數名不能含 `/` → `not a valid identifier` → set -e 中止。

### 🔴 `git config --get user.name` 會走全部 scope

沒 `--local` 時,git 走 system → global → local → worktree。意圖是「local 沒設才填」,但全域有時永遠不會 fall through。**必須加 `--local`**。

### 🔴 cp 相對路徑 vs 檢查絕對路徑(L138 早期版本)

```bash
[ -f "$TARGET_DIR/$SK_PROJECT/CLAUDE.md" ] && cp -f CLAUDE.md CLAUDE.md.sk-init.bak
```

檢查的是 `$SK_PROJECT/CLAUDE.md`,但 cp 用相對路徑解析(cwd = `$TARGET_DIR`),拷的是父層的 CLAUDE.md(完全不同檔)。修法:全用絕對路徑,或抽函式統一處理。

### 🟡 `--force` 與 `--here` flag 互動

兩者都用同一個 `force` 變數,但效果不同:
- 目錄層:`--force` 才允許 merge 進既有目錄
- 檔案層:`force=True` 覆寫,`force=False` skip 保護

要「進既有目錄又保護既有檔」**只能** `--here` + `echo y` 自動 confirm,不可加 `--force`。

### 🟡 spec-kit init 後 `.specify/extensions/`、`.claude/skills/speckit-git-*/`、`.specify/init-options.json`、`.specify/workflows/` 必然 untracked

這是 spec-kit 流程設計:`init_git_repo()` 跑完才安裝 extensions/presets,沒有第二次 `git add`。腳本必須補 follow-up commit。

---

## 風格約定(已存入記憶)

存於 `~/.claude/projects/.../memory/feedback_bash_review_style.md`:

1. **被 regex 驗證過的變數沒包雙引號** — 視為已實質安全(縱深防禦不主動提)
2. **目錄路徑尾端 `/`**(任何位置:`cd`、函式參數、`[ -d ]`、字串拼接)— 使用者刻意保留作為「**這是目錄**」的視覺標記,看 code 時很明確;即使造成路徑拼接出 `//`(雙斜線),也用下游 sed 或 `${var%/}` normalize 而非犧牲視覺辨識

未來 review 不再針對這兩項提醒。

### 其他風格決策

- `[ ]` vs `[[ ]]` 混用:不強制統一(已決)
- `SK_VERSION` 寫死 `v0.8.1`(三處硬編)而非抽 `SK_VERSION_MIN` 常數(已決,使用者選擇)
- 升級流程不自動跑,只給使用者 5 步指引(已決)
- 備份檔名用 UTC + `Z` 後綴(已決)
- `read -p` 全部改 `read -rp`(SC2162)(已修)
- 錯誤訊息一律 `>&2` 導 stderr(已修)

---

## 最終腳本流程圖

```
[啟動]
  ├─ pre-flight: uvx, git 存在?
  ├─ 收集 TARGET_DIR、設預設值
  ├─ 互動輸入:SK_PROJECT, SK_VERSION, GIT_USER_NAME, GIT_USER_EMAIL
  ├─ 各欄位 regex / 版號驗證(失敗 exit 1)
  ├─ 檢查 $SK_PROJECT/.git 是不是檔案(worktree/submodule)→ exit 1
  ├─ Identity 設定(只在使用者改了 default 時)
  │     ├─ 已是 repo → 條件式 `git config --local`
  │     └─ 不是 repo → git init + 強制設定
  └─ 主分派(四象限):
        ├─ 目錄不存在     → spec-kit 自動 init + follow-up commit
        ├─ 已有 .specify/  → 升級提示 + exit 1
        ├─ 已有 .git/      → backup CLAUDE.md → spec-kit --here --no-git → follow-up commit
        └─ 都沒有          → 詢問 --force → backup → spec-kit --force
```

八個情境路徑全部閉環、無 dead branch、無 crash、無衝突。

---

## 後續 TODO(若要 ship 為 v1)

1. L2 timestamp 升至 `###ANEW:20260428a`(會話收尾日期)
2. (可選)抽 `SK_VERSION_MIN` 常數讓三處硬編集中(使用者已決定不做)
3. (可選)L65 `.specify/` 升級分支從「只印提示」改為「自動跑 `git checkout -b` + spec-kit + diff」 — 等 spec-kit 上游真的提供 upgrade 指令再考慮
4. 把 `.env.spec-kit` 加進 `.gitignore`(若使用者後續想恢復環境變數模式)

---

## 相關檔案

- 腳本:`./claude-superspec-init.sh`
- 對照 v0.7.5 範例:`./spec-kit-docker-nodejs/`
- 對照 v0.8.1 範例:`./test/`(已 init)、`./test2/`(同 init,只差 timestamp)
- 記憶:`~/.claude/projects/-mnt-d-AnewSpaces-Local-x-Project-TEST-claude-claude-telegram/memory/feedback_bash_review_style.md`
- spec-kit 原始碼參考:`https://github.com/github/spec-kit/blob/v0.8.1/src/specify_cli/__init__.py`
- spec-kit releases:`https://github.com/github/spec-kit/releases`
