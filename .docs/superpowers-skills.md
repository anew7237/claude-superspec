# superpowers 可用 skills（14 個）

## 計畫與執行類

| Skill | 用途（中譯） |
|---|---|
| `superpowers:brainstorming` | **必須**於任何創作類工作前使用——新增功能、建構元件、擴充行為、修改行為。先釐清使用者意圖、需求與設計，再動手實作。 |
| `superpowers:writing-plans` | 當你有多步驟任務的規格或需求時使用，在動程式碼之前先寫計畫。 |
| `superpowers:executing-plans` | 當你已寫好實作計畫，要在獨立 session 中搭配審查檢查點逐步執行時使用。 |
| `superpowers:subagent-driven-development` | 於當前 session 執行含獨立子任務的實作計畫時使用。 |
| `superpowers:dispatching-parallel-agents` | 面對 2 個以上彼此獨立、無共享狀態、無順序依賴的任務時使用。 |

## 開發流程類

| Skill | 用途（中譯） |
|---|---|
| `superpowers:test-driven-development` | 實作任何功能或修 bug 前使用，在寫實作程式碼之前先寫測試。 |
| `superpowers:systematic-debugging` | 遇到 bug、測試失敗、非預期行為時，在提出修法之前先用這個系統化除錯流程。 |
| `superpowers:verification-before-completion` | 當你將宣稱「完成／修好／通過」時使用——在 commit 或建 PR 前，必須先執行驗證指令並確認輸出，證據先於宣稱。 |
| `superpowers:finishing-a-development-branch` | 當實作完成、測試全綠、需要決定如何整合時使用，以結構化選項引導 merge、PR 或清理。 |
| `superpowers:using-git-worktrees` | 開始需與當前工作區隔離的功能開發時，或執行實作計畫前使用，建立有智慧目錄選擇與安全驗證的 git worktree。 |

## 程式碼審查類

| Skill | 用途（中譯） |
|---|---|
| `superpowers:requesting-code-review` | 完成任務、實作大功能、合併前使用，以驗證成果是否符合需求。 |
| `superpowers:receiving-code-review` | 收到 code review 意見時、實作建議前使用，尤其是意見看起來不清楚或技術上有疑慮時——需要技術嚴謹與驗證，不是表面附和或盲目照做。 |

## meta／工具類

| Skill | 用途（中譯） |
|---|---|
| `superpowers:using-superpowers` | 任何對話開始時使用——建立「如何尋找並使用 skills」的規範；要求在任何回應（含釐清問題）之前先呼叫 Skill 工具。 |
| `superpowers:writing-skills` | 建立新 skill、編輯既有 skill、部署前驗證 skill 是否運作正常時使用。 |
