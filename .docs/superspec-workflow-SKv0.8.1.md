# SuperSpec - Claude Code 環境下使用 Superpowers + Spec-Kit 整合開發流程(修正版 v2026.04.28e)
# (`!!!僅適用於 Spec-Kit@v0.8.1 以上版本!!!`)

> **重要**: [Spec-Kit@v0.8.1 (2026/04/25 Release)](https://github.com/github/spec-kit/releases/tag/v0.8.1),將 斜線指令 `/speckit.*` 改為 `/speckit-*`
>
> 整理自[忍者工坊「用 superpowers 與 spec-kit 打造 AI 輔助開發流程」](https://nijialin.com/2026/02/18/superpowers-vs-spec-kit/)一文,並補充 superpowers / spec-kit 官方文件中的延伸用法。

---

## 標籤示例

| 標籤 | 意義 | 說明 |
|---|---|---|
| 🔵 **加料** | 忍者工坊原文未明確提及 | 從 Superpowers / Spec-Kit 官方文件補的 |
| 【Shell端】| powsershell / bash / zsh | Shell端 依不同 `OS環境`,指令可能有所不同 |
| 【CC原生】| Claude Code 內建指令 / 機制 | 與兩個框架無關 |
| 【SK指令】| Spec-Kit 斜線指令 | 以 `/speckit-` 開頭(注意不是點號, 是 **`-`**) |
| 【SK檔案】| Spec-Kit 產生/管理的檔案 | 由 Spec-Kit 指令自動產生與維護 |
| 【SP技能】| Superpowers Skill | 由模型依情境**自動觸發** (skills 本身**沒有**同名斜線指令) |
| 【SP範本】| Superpowers Skill 提示詞範本 | 由【SP技能】`subagent-driven-development` 內部派發使用 |

> **重要**:原本**帶斜線**的 `/superpowers:<brainstorm|write-plan|execute-plan>` 斜線指令已**全面棄用**

---

## 階段 0:環境準備(一次性)

### 要執行的動作

| 步驟 | 標籤 | 動作 | 說明 |
|---|---|---|---|
| 0.0 | 【Shell端】 | `uvx --from git+https://github.com/github/spec-kit.git@v0.8.1 specify init <project> --integration claude` | 為專案裝上指定tag版本的 **Spec-Kit** |
| 0.1 | 【Shell端】 | `uvx --from git+https://github.com/github/spec-kit.git@v0.8.1 specify extension add git` | 為專案裝上 **Spec-Kit** Extension |
| 0.2 | 【Shell端】 | `cd <project> && git config user.name '<name>' && git config user.email '<email>' && echo '.claude/' > .gitignore` | 專案初始化 **Git** |
| 0.3 | 【CC原生】| `/plugin marketplace add obra/superpowers-marketplace` (Superpowers 添加市集) | **僅需執行一次** |
| 0.4 | 【CC原生】| `/plugin install superpowers@superpowers-marketplace` (Superpowers 全域安裝) | **僅需執行一次** |

> 🔵 **建議**:`specify init` 請釘版本 tag(例如 `@v0.8.1`),不然會拉 `main`,行為可能隨上游變動。官方 README 推薦這麼做。
>
> 🔵 **快速**:步驟 0.0~0.2 使用本專案撰寫的腳本 [claude-superspec-init.sh](https://github.com/anew7237/claude-superspec/blob/main/claude-superspec-init.sh) 進行安裝
> ```
> bash <(curl -fsSL https://raw.githubusercontent.com/anew7237/claude-superspec/main/claude-superspec-init.sh)
> # 若無 curl, 可改用 wget -qO- https://...
> ```
> 跑完 `specify init` 後,`/speckit-*` 系列指令會被寫進 `.claude/commands/`,Claude Code 重啟後 【SK指令】 就能使用。

### 產生/涉及的檔案

```
CLAUDE.md       ← **專案層級記憶**
.specify/       ← (v0.8.1)
├── memory/
│  └── constitution.md       ← **專案治理原則**
├── extensions/               ← 擴充套件目錄(未展開)
├── extensions.yml            ← 擴充套件(要裝 git extension)
├── init-options.json
├── integration.json
├── integrations/
│   ├── claude.manifest.json
│   └── speckit.manifest.json
├── scripts/                  ← 腳本(目錄未展開)
├── templates/                ← 範本(目錄未展開)(包含 constitution spec plan tasks checklist)
└── workflows/
     ├── speckit/
     │   └── workflow.yml
     └── workflow-registry.json
```

---

## 階段 1:Superpowers Brainstorm(發想)

核心觀點:**Brainstorm 交給 Superpowers,因為它的蘇格拉底式提問比 Spec-Kit 的 specify 更會「逼你想清楚」。**

| 步驟 | 標籤 | 動作 | 說明 |
|---|---|---|---|
| 1.1 | 【SP技能】 | `superpowers:brainstorming <想做什麼功能>` | 明確觸發【SP技能】`brainstorming` |
| 1.2 | 【SP技能】 | (由 1.1 觸發的【SP技能】`brainstorming`) | 持續互動:AI 進入蘇格拉底式提問,一題一題回答、選方案、分段 review |
| 1.3 | 【SP技能】 | (由 1.1 觸發的【SP技能】`brainstorming`) | **ExitPlanMode前結束**:產出設計草稿 (不要進 write-plan!!!) |
| 1.4 | 【CC原生】 | (提示詞: 上面對話後臨時存的檔案在哪?) | 檔案會存在 **~/.claude/plan/**,可以授權讓它轉存在當前project目錄 |
| 1.5 | 【CC原生】 | `/clear` (清空對話,進下個 session 🔵) | 積極清理上下文 |

> **重點**:刻意停手,不讓 Superpowers 自動銜接到 `superpowers:write-plans`——文件化的工作要交給 Spec-Kit。
>
> 🔵 **關於 1.5 的 `/clear`**:忍者工坊原文只說「碰到 rate limit 就等,下個 session 接著做」,沒強制「每階段必 clear」。此處的 `/clear` 是本文主動的積極策略,目的是讓下個階段起始 context 乾淨——若你一路順暢沒撞 rate limit,跳過也可以。

---

## 階段 2:Spec-Kit 文件化(規格正式化)

### 2.0 前置:設定專案治理原則(一次性)

| 步驟 | 標籤 | 動作 | 說明 |
|---|---|---|---|
| 2.0 | 【SK指令】 | `/speckit-constitution` →【SK檔案】`.specify/memory/constitution.md` | 設定專案治理原則=立憲(整個專案只做一次,後續可更新) |

> 若治理原則需要調整,再單獨重跑 `/speckit-constitution` 即可(不需要每次新功能都跑)。

### 2.1 ~ 2.6 每個功能的規格化流程(每次新需求都跑)

把 brainstorm 出來的設計餵給 Spec-Kit,跑 SDD 流程,把規格變成「可追溯的活文件」(SSOT)。

| 步驟 | 標籤 | 動作 | 說明 |
|---|---|---|---|
| 2.1 | 【SK指令】 | `/speckit-specify` →【SK檔案】`spec.md` | 把 階段 1 設計內容貼進去,產出規格文件 |
| 2.2 | 【SK指令】 | `/speckit-clarify` (官方列為 optional 🔵) | 結構化澄清模糊處,記錄到 Clarifications 段落 |
| 2.3 | 【SK指令】 | `/speckit-plan` →【SK檔案】`plan.md` | 生成技術計畫(架構、技術棧、依賴) |
| 2.4 | 【SK指令】 | `/speckit-tasks`→【SK檔案】`tasks.md` | 把 plan 拆成可執行的任務清單 |
| 2.5 | 【SK指令】 | `/speckit-analyze` (官方列為 optional 🔵) | 一致性檢查(spec / plan / tasks 對得上嗎) |
| 2.6 | 【CC原生】 | `/clear` (清空對話,進下個 session 🔵) | 積極清理上下文 |

> **關鍵**:這裡刻意**不跑** `/speckit-implement`,實作交給下個階段的 Superpowers。這就是組合的精髓——Spec-Kit 負責規格, Superpowers 負責執行紀律。
>
> 本流程選擇以 Superpowers 的 subagent + TDD 取而代之,屬於**自覺的取捨**(trade-off):放棄 Spec-Kit 單一工具的流暢,換 Superpowers 在執行紀律上的強項。

### 生成的檔案結構【SK檔案】:

```
.specify/
├── memory/
│   └── constitution.md          ← /speckit-constitution
└── (每個 feature 一個資料夾)
specs/
└── <NNN-feature-name>/          ← /speckit-specify (每個 feature 一個資料夾, NNN 編號自動加1)
    ├── plan.md                  ← /speckit-plan
    ├── research.md              ← /speckit-plan
    ├── data-model.md            ← /speckit-plan
    ├── quickstart.md            ← /speckit-plan
    ├── contracts/               ← /speckit-plan
    ├── checklists/              ← /speckit-checklist
    ├── tasks.md                 ← /speckit-tasks (階段 3.1 execute-plan 的執行輸入)
    └── spec.md                  ← /speckit-specify (階段 3.2 Spec compliance reviewer 審查的真相來源)
                                (└ 含 /speckit-clarify 記錄的 Clarifications 段落)
```

---

## 階段 3:Superpowers Execute-Plan(執行)

### 3.0 前置

| 步驟 | 標籤 | 動作 | 說明 |
|---|---|---|---|
| 3.0.0 | 【CC原生】 | 提示詞: `以下提到 <NNN-feature-name> 即是當前 worktree 分支名` 🔵 | 定義給 Claude Code 知道 |
| 3.0.1 | 【SP技能】 | `superpowers:verification-before-completion` 🔵 | 確認測試 baseline 全綠 |

> **補充**:正常 verification-before-completion 之前,會用 using-git-worktrees 建立新的分支,但speckit階段已經建立新的分支

### 3.1 啟動 loop

把 Spec-Kit 產出的 `tasks.md` 餵回 Superpowers,享用 subagent 隔離 context 的好處。

| 步驟 | 標籤 | 動作 | 說明 |
|---|---|---|---|
| 3.1 | 【SP技能】 | `superpowers:executing-plans` +【SK檔案】`tasks.md` | 把 Spec-Kit 的 tasks 餵給 Superpowers,啟動執行 |

> **提示詞輸入**: superpowers:executing-plans 讀 specs/<NNN-feature-name>/tasks.md,用 superpowers:subagent-driven-development + TDD 一個一個跑,spec compliance 審查時對照 specs/<NNN-feature-name>/spec.md
>              └ 即進行 3.2 的 loop 派遣 implementer subagent
> superpowers:subagent-driven-development — 使用者指定的執行模式 skill,給出「per-task / per-phase 派發 implementer subagent → spec reviewer → code quality reviewer」的流水線設計,以及 implementer-prompt.md / spec-reviewer-prompt.md / code-quality-reviewer-prompt.md 範本。


### 3.2 每個任務的 loop(這是圖上的核心,非手動觸發)

實際關係是 **Superpowers 派遣 → Claude Code 跑 subagent**。每個任務都會走完下面這幾步:

| 步驟 | 標籤 | 動作 | 說明 |
|---|---|---|---|
| 3.2.1 | 【SP技能】 | `subagent-driven-development` | `Superpowers 協調器` **派遣全新 implementer subagent**(乾淨 context window) |
| 3.2.2 | 【SP技能】 | `test-driven-development` | `implementer subagent` 寫 code,嚴格走 Red→Green→Refactor |
| 3.2.3-a | 【SP範本】 | spec-reviewer-prompt.md | `Spec compliance reviewer` **拿著 Spec-Kit 的 spec 對照實作**(做出來的東西是否符合規格) |
| 3.2.3-b | 【SP範本】 | code-quality-reviewer-prompt.md | `Code quality reviewer` code 寫得好不好?測試夠不夠?(這階段不看 Spec-Kit 的 spec) |
| 3.2.4 | 【SP技能】 | `subagent-driven-development` | `Superpowers 協調器` 收到 subagent 回報,任務完成,進下一個任務(回 3.2.1 或結束往下) |

> **兩階段審查的順序很重要**:先確認方向對(3.2.3-a),再談品質(3.2.3-b)。方向錯了,code 寫再漂亮都白工。
>
> 🔵 忍者工坊原文只提到 Superpowers 有「先查規格符合度,再查 code 品質」的自動 review 機制;「spec compliance reviewer subagent / code quality reviewer subagent」這兩個角色名是本文為了敘事方便而取的,**不是** subagent-driven-development skill 裡的正式術語。實際行為以 skill 當下的實作為準。
>
> **!!!注意!!!**:此階段結束,尚不要進行分支 `worktree 結束` 的建議(superpowers:executing-plans 結束時它會再提示 `worktree 結束` 的選項)

---

## 階段 4:收尾 🔵

原文沒明確提這段,但官方文件有,中大型功能或團隊協作建議補上。

| 步驟 | 標籤 | 動作 | 說明 |
|---|---|---|---|
| 4.1 | 【SP技能】 | `superpowers:requesting-code-review` +【SK檔案】`spec.md` | 對照 Spec-Kit 規格做完整 Code Review |
| 4.2 | 【SP技能】 | `superpowers:verification-before-completion` 🔵 | 完成前驗證(全測試、lint、型別) |
| 4.3 | 【SP技能】 | `superpowers:finishing-a-development-branch` 🔵 | 處理合併或開 PR、清理 worktree |

---

## 修正版的指令範例(每行都標註出處)

```bash
# === 階段 0:一次性設定 ===
# Shell端(釘 tag 建議,最小版本至少 v0.8.1):
$ uvx --from git+https://github.com/github/spec-kit.git@v0.8.1 specify init my-app --integration claude

# Claude Code 端(兩行都是在 Claude Code 裡輸入,不是 shell):
你:「/plugin marketplace add obra/superpowers-marketplace」   # 【CC原生】
你:「/plugin install superpowers@superpowers-marketplace」    # 【CC原生】

# === 階段 1:Superpowers Brainstorm ===
你:「superpowers:brainstorming <想做什麼功能>」
    └─ 進入蘇格拉底式問答                # 【SP技能】
你: (回答 N 輪問題,確認設計草稿)
你:「上面對話後臨時存的檔案在哪?」         # 【CC原生】(ExitPlanMode前,不要進 write-plan!!!)
你:「/clear」                              # 【CC原生】🔵(清理上下文)

# === 階段 2:Spec-Kit 文件化 ===

# 2.0 前置(一次性,已做過請跳過)
你:「/speckit-constitution」                # 【SK指令】(整個專案只跑一次)

# 2.1 每個功能的規格化流程
你:「/speckit-specify 讀取<brainstorming產出的.md檔>」 # 【SK指令】
你:「/speckit-clarify」                    # 【SK指令】🔵(官方 optional)
你:「/speckit-plan <以上面spec寫成plan>」  # 【SK指令】(/speckit-clarify 後會引導)
你:「/speckit-tasks」                      # 【SK指令】
你:「/speckit-analyze」                    # 【SK指令】🔵(官方 optional)
你:「/clear」                              # 【CC原生】🔵(清理上下文)

(git commit plan 所產生的檔案,**也可不commit**)

# === 階段 3:Superpowers Execute-Plan ===

# 3.0 前置 🔵(<NNN-feature-name> 是由 Spec-Kit 開的分支 )
你:「以下提到 <NNN-feature-name> 即是當前[git branch]名稱」
你:「superpowers:verification-before-completion」
    └─【SP技能】 verification-before-completion (自動讀取 specs/<NNN-feature-name>/)

# 3.1 + 3.2 啟動 loop(這是圖上的核心)
你:「superpowers:executing-plans 讀 specs/<NNN-feature-name>/tasks.md,
     用 superpowers:subagent-driven-development + TDD 一個一個跑,
     spec compliance 審查時對照 specs/<NNN-feature-name>/spec.md」
    └─【SP技能】 啟動整個 loop
       loop 內每個 task:
       ├─ 1. 派遣 implementer subagent(乾淨 context)
       ├─ 2. implementer 用 test-driven-development 走 Red→Green→Refactor   # 【SP技能】
       ├─ 3-a. spec compliance reviewer 拿 spec.md 對照實作           # 【SK檔案】真相來源
       ├─ 3-b. code quality reviewer 看 code 品質
       └─ 4. 任務完成,進下一個

(git commit tasks 所產出/異動的程式碼)

# === 階段 4:收尾 🔵 ===

你:「superpowers:requesting-code-review 對照 specs/<NNN-feature-name>/spec.md 做 review」
    └─【SP技能】
你:「superpowers:verification-before-completion 幫我做完成前驗證,跑全測試、lint、型別檢查」
    └─【SP技能】
你:「superpowers:finishing-a-development-branch 收尾,開 PR、清理 worktree」
    └─【SP技能】
```

---

## 文章作者的實戰心得(原文引用為主)

| 觀察 | 對應策略 |
|---|---|
| 「兩個工具用下來,大概都是 1.5 小時就碰到 rate limit」 | 不可避免,只能拆 session |
| 作者的「無腦用法」:**「用一個 session 想清楚、把文件搞定,碰到 rate limit 就等,下個 session 再繼續執行」** | 把 rate limit 當自然的切換點,用 Spec-Kit 的文件當 session 間的交接介面 |
| 任務切越小、單次對話越短,越不容易做到一半斷掉 | 階段 2 的 `/speckit-tasks` 切到夠細,階段 3 才能小步快跑 |

> 🔵 **本文主動策略**:在每個階段結束都 `/clear`(而不只是撞 rate limit 才換 session),讓下個階段的 context 絕對乾淨。這是本文作者的建議,不是忍者工坊原文的規定——用不用都合理,主要看你的節奏。
>
> 三階段流程天然契合「session 中斷不丟脈絡」——`specs/<feature>/` 裡的文件就是交接介面,即使 rate limit 中斷,下個 session 開起來指著那份 spec 就能繼續。

---

## 三階段流程一句話總結

> **Superpowers Brainstorm**(發想)→ **Spec-Kit specify/plan/tasks**(文件化)→ **superpowers execute-plan**(執行)
>
> 文章作者引用 Superpowers 作者 Jesse Vincent 在 GitHub Issue 親自背書的話:Brainstorm 用 Superpowers、把需求正式化用 Spec-Kit,這兩個工具組合得很好。
>
> 兩個工具背後想教的同一件事:**不要一拿到需求就叫 AI 寫 code,先想清楚再動手,成果差很多。**
