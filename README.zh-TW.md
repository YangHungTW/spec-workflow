# Specaffold

為 Claude Code 設計的、以 spec 為驅動的角色制開發流程。由一個小型虛擬團隊(PM、Designer、Architect、TPM、Developer、QA-analyst、QA-tester)透過一系列編號 markdown 產物推進每個功能。

English version: [README.md](README.md)

另見:[README.md](README.md)

## 安裝

### 1. 一次性全域 bootstrap

從本 repo 執行,在 `~/.claude/` 下建立受管理的 symlinks:

```sh
bin/claude-symlink install
```

這會安裝目錄 symlinks:`~/.claude/agents/scaff`、`~/.claude/commands/scaff`、`~/.claude/hooks`、`~/.claude/skills/scaff-init` — 讓 Specaffold 的 agents、commands、hooks,和 `/scaff-init` bootstrap skill 在這台機器上的每個 Claude Code session 都能用。**Repo-local team-memory 刻意不 symlink 為 user-global**;詳見下方 [Team memory](#team-memory)。`install` / `uninstall` / `update` / `--dry-run` 細節見下方 [`bin/claude-symlink`](#binclaude-symlink--全域-symlink-管理工具) 區塊。

### 2. 針對單一 consumer repo 初始化

在 **目標 consumer repo 內** 執行 init skill:

```
/scaff-init
```

在無互動或腳本化情境下,直接呼叫 seed binary:

```sh
<src>/bin/scaff-seed init --from <src> --ref HEAD
```

將 `<src>` 換成本 repo 的絕對路徑,`<ref>` 換成你想釘定追蹤的 commit 或 tag。

**`init` 做什麼:**

- 將 `.claude/agents/scaff`、`.claude/commands/scaff`、`.claude/hooks`、`.claude/rules`、`.claude/team-memory` 骨架種到 consumer repo。
- 種下 `.specaffold/features/_template/` 作為 feature scaffold。
- 在 repo 根目錄寫入 `specaffold.manifest`,記錄釘定的 source ref 與每檔 baseline hash,供未來 `update` 比對使用。
- 用原子式 read-merge-write(若有既存檔先做 `.bak` 備份)把 consumer-local hook 路徑寫進 `settings.json`(SessionStart + Stop)。

### 3. 升版到更新的 ref

當你想採用較新版 Specaffold 時重跑 `update`:

```sh
bin/scaff-seed update --to <new-ref>
```

每檔行為:

- 與新 ref 下 source 逐 byte 相同:回報 `already`,不動。
- 與 manifest 中 **上一版 ref baseline** 相同(即未被本地修改):以新內容覆蓋,回報 `replaced:drifted`;覆寫前的內容存成 `<path>.bak`。
- 與 source **和** baseline 都不同(使用者已修改):跳過並回報 `skipped:user-modified`;本地編輯保留。
- 只有整次執行完全沒有 `skipped:user-modified` 時,manifest ref 才會推進。若有任何檔被跳過,先處理衝突(見 [Verb vocabulary](#verb-vocabulary) 與 [Recovery](#recovery)),再重跑。

### 逐專案隔離保證

每個 consumer repo 以自己的 `specaffold.manifest` 釘在自己的 ref 上。Team-memory 檔是 consumer 本地所有,不會回流到 source repo。同一台機器上兩個 consumers 可以並行使用不同版本的 Specaffold、互不干擾。

### Recovery

若某次 `update` 留下 `skipped:user-modified` 的檔,manifest ref **不會** 推進。處理方式:

1. 比對你的檔案與 new source 的 diff。
2. 擇一:保留你的編輯(自行把檔複製成 `<path>.bak`,然後重跑 `update` — 工具會當成 baseline-matched 而覆蓋),或是丟棄(從 manifest baseline 還原,再重跑)。
3. 當一次 run 完全無衝突,manifest 推進到新 ref。

若需回滾,從工具產出的 `.bak` 檔還原即可。

---

## 語言偏好設定

Specaffold 提供 opt-in 的對話回覆語言偏好。設定檔為 `.specaffold/config.yml`,由使用者自行撰寫;預設為 repo local、不會被推到共用分支。想讓這份偏好在多人共享的人,可以刻意 commit 進 repo。

檔案不存在,或 `lang.chat` key 未設定,等同 default-off:保留全英文行為。此設定嚴格 opt-in,沒設就沒效果。

### Config key: `lang.chat`

把 `lang.chat` 設成 `zh-TW`(或其他 BCP-47 tag)以啟用對話回覆在地化。無法辨識的值會產生警告並 fallback 到 default-off 行為。

```yaml
# .specaffold/config.yml
lang:
  chat: zh-TW    # 或 "en"(明示預設) — 其他值 → 警告 + default-off
```

SessionStart hook 讀這個檔;當 `lang.chat: zh-TW` 有設時,會把 `LANG_CHAT=zh-TW` marker 注入 session 脈絡,讓每個 Specaffold subagent 角色都尊重這個偏好,而不需要每個 agent 各自處理。完整條件與 carve-out 規則(檔案內容、CLI stdout、commit message、team-memory 檔案不論設定值一律保持英文)載於 `.claude/rules/common/language-preferences.md`。

### 優先序

Hook 依序檢查下列候選,取第一個有 `lang.chat` key 的檔案(即使值不合法也停在此):

1. `.specaffold/config.yml` — 專案層級(repo-local)。
2. `$XDG_CONFIG_HOME/specaffold/config.yml` — 僅當 `$XDG_CONFIG_HOME` 已設且非空。
3. `~/.config/specaffold/config.yml` — user-home fallback。

當較早候選出現不合法值(不在 `{zh-TW, en}` 之內),會輸出一條指名該檔的 stderr 警告,該 session 回落為英文預設。迭代 **不會** 越過不合法的較早候選繼續往較晚的走 — 不合法檔案被視為刻意的「這是我設的、請修正 typo」訊號,不是可以繞過的疏漏。

多數使用者把 `~/.config/specaffold/config.yml` 設好一次忘掉即可;專案層級是給團隊共用覆蓋用。

### 繞過機制

有兩個 escape hatch 供特定 commit 或特定檔必須抑制語言偏好時使用:

- **緊急(commit 層級):** `git commit --no-verify` 跳過所有 pre-commit hook,包括強制偏好的 Specaffold linter。謹慎使用;此繞過不會自動被稽核。
- **精細(逐檔):** 在檔案中加入 HTML 註解,linter 執行時會辨識:
  ```
  <!-- scaff-lint: allow-cjk reason="..." -->
  ```
  此標記讓 linter 對該檔免檢,其他檔仍受一般強制。

---

## Flow

```
/scaff:request      → PM 進件(若未給 --tier,會 propose 一個 tier)
/scaff:design       → Designer 產出 mockup — 僅當 has-ui: true
/scaff:prd          → PM 撰寫需求文件
/scaff:tech         → Architect 選技術 + 系統架構設計
/scaff:plan         → TPM 寫合併式 plan(narrative + task checklist)
/scaff:implement    → Developer 以 worktree 平行跑 waves + inline review
/scaff:validate     → QA-tester + QA-analyst 平行驗證;verdict 為 PASS / NITS / BLOCK
/scaff:archive      → TPM 跑 retrospective + 搬到 archive
```

**工作類型進件指令**(非 feature 工作的 `/scaff:request` 替代品):

```
/scaff:bug   <input>   → PM 進件,適用 fix 類工作
/scaff:chore <input>   → PM 進件,適用維護/清理工作
```

**`/scaff:bug`** — 用於 fix 類進件。`<input>` 參數會自動分類:
- URL(例如 `https://github.com/user/repo/issues/123`)→ `type: url`
- Ticket ID(例如 `PROJ-456`)→ `type: ticket-id`
- 自由描述文字 → `type: description`

Slug 命名規則:`YYYYMMDD-fix-<body>`。PM 探詢項目:重現步驟、預期行為 vs 實際行為、環境資訊。PRD 樣板以 bug 為形(Repro / Expected / Actual / Environment / Root cause / Fix requirements / Regression test requirements)。封存時,retrospective 聚焦 **guardrail 缺口** — 哪些檢查或測試能更早發現此問題。

**`/scaff:chore`** — 用於維護/清理進件。Slug 命名規則:`YYYYMMDD-chore-<body>`。PM 探詢項目:範疇、原因、驗證斷言。PRD 樣板為 checklist 形式(待辦項目 + 驗證斷言)。封存時,retrospective 聚焦 **自動化潛力** — 哪些反覆的手動工作可以自動化。

Feature 工作仍以 `/scaff:request` 為進件入口。其 retrospective 聚焦 **技術決策** — 功能開發期間架構與函式庫選擇的理由。

捷徑 — 依 STATUS 一次推進一個階段:

```
/scaff:next <slug>
```

修訂指令:

```
/scaff:update-req    /scaff:update-tech    /scaff:update-plan    /scaff:update-task
```

多軸 review(一次性、不推進 STATUS,任何階段都可跑):

```
/scaff:review <slug>                      # 三軸齊發:security、performance、style
/scaff:review <slug> --axis security      # 單軸重審
```

Team memory:

```
/scaff:remember <role> "<lesson>"          # 手動保存
/scaff:promote <role>/<file>               # local → global
```

雙層 memory:`~/.claude/team-memory/<role>/`(global)+ `<repo>/.claude/team-memory/<role>/`(local)。每次 agent 被喚起時兩層都讀。`/scaff:archive` 會跑 retrospective,對每個角色提問是否有心得值得保存。完整協議見 `.claude/team-memory/README.md`。

## Layout

```
.claude/
  agents/scaff/        pm.md designer.md architect.md tpm.md developer.md
                       qa-analyst.md qa-tester.md
                       reviewer-security.md reviewer-performance.md reviewer-style.md
  commands/scaff/      request.md design.md prd.md tech.md plan.md
                       implement.md validate.md review.md archive.md
                       next.md remember.md promote.md
                       update-req.md update-tech.md update-plan.md update-task.md
  hooks/               session-start.sh stop.sh
  rules/               common/ bash/ markdown/ git/ reviewer/
                       README.md index.md
  team-memory/         pm/ designer/ architect/ tpm/ developer/
                       qa-analyst/ qa-tester/ shared/
                       README.md
  skills/scaff-init/   (per-project 安裝 skill)

.specaffold/
  config.yml           (選用 — 語言偏好)
  features/
    _template/         (feature scaffold,由 /scaff:request 複製)
    <slug>/
      00-request.md
      02-design/       (僅當 has-ui: true)
      03-prd.md
      04-tech.md
      05-plan.md       (合併:narrative + task checklist)
      08-validate.md
      STATUS.md
  archive/<slug>/

bin/
  scaff-seed           (專案 init / update / migrate)
  scaff-tier           (讀取 tier 欄位的唯一 helper)
  scaff-aggregate-verdicts
  scaff-install-hook
  scaff-lint

settings.json          (Claude Code 設定;SessionStart + Stop hook 接線)
```

## Tier 模型

每個 feature 帶有一個 **tier**,決定哪些階段是必要、哪些可選、哪些完全略過。Tier 於 `/scaff:request` 時宣告,且是單調遞增的 — 只能升不能降。

### 三個 tier

| Tier | 意圖 | 典型規模 |
|---|---|---|
| `tiny` | 錯字、單一 function 微調、文案修正 | < 1 天 |
| `standard` | 一般功能或 bugfix | 1–5 天 |
| `audited` | 身分驗證、secrets、breaking API、高風險變更 | 不限規模 |

### Stage 對照表

Tier → stage dispatch 表(✅ 必要、🔵 可選、⚫ 視 `has-ui: true` 決定、— 略過):

| Stage | tiny | standard | audited |
|---|:---:|:---:|:---:|
| request | ✅ | ✅ | ✅ |
| prd | ✅(允許一行) | ✅ | ✅(必要附 `## Exploration`) |
| tech | — | ✅ | ✅ |
| plan | 🔵 | ✅ | ✅(細粒度 wave 切分) |
| design | — | ⚫ | ⚫ |
| implement | ✅ | ✅ | ✅ |
| validate | ✅(預設只跑 tester 軸) | ✅(雙軸) | ✅(雙軸) |
| review | 🔵 | 🔵 | ✅(三軸齊發為必要) |
| archive | ✅ | ✅(merge-check) | ✅(merge-check 嚴格) |

`/scaff:next` 讀取 `STATUS.md` 中的 `tier:` 欄位,略過該 tier 不需要的階段,並為每個略過的階段寫一條 STATUS Note。

略過邏輯由 **3×3 工作類型 × tier 矩陣**延伸,實作於 `bin/scaff-stage-matrix`。工作類型(`feature` / `bug` / `chore`)與 tier(`tiny` / `standard` / `audited`)共同決定每個 stage 是必要、可選還是略過。主要規則:`chore` 工作類型無論任何 tier 都略過 design stage;`bug-tiny` 仍需跑 validate(最小修正也需要回歸測試)。

### 在 request 時宣告 tier

用 `--tier` 明示指定:

```sh
/scaff:request --tier tiny "fix typo in README"
/scaff:request --tier audited "rotate OAuth secrets"
```

若沒帶 `--tier`,PM 會依 raw ask 提議一個 tier 並進入 **propose-and-confirm**:直接按 Enter 接受提議,輸入不同值則覆寫。PM 絕不在未提議前靜默採用預設值。

### 單調升級規則

Tier 升級是 **單向的**:`tiny → standard → audited`。任何會寫 `tier:` 欄位的指令都會拒絕降級。嘗試降級會 exit non-zero,不改動 STATUS。

**自動升級觸發**:

- `/scaff:implement` 偵測到 diff 超過 200 行 **或** 超過 3 檔 → 建議 `tiny → standard`(由 TPM 決定是否接受)。
- 任一 reviewer 產生 `must`-severity 的 **security** finding → 立即自動升到 `audited`,無需確認。
- PRD 觸及 security-sensitive 路徑(auth、secrets、`settings.json`)→ PM 在 PRD 階段建議升 `audited`。

### 稽核軌跡

每次 tier 變更會附一條 STATUS Notes:

```
YYYY-MM-DD <role> — tier upgrade <old>→<new>: <trigger-reason>
```

沒有這條 note 的 tier 變更視為無效。常見 trigger-reason 值:`TPM veto at plan`、`security BLOCK auto-upgrade`、`diff exceeded threshold`。

### Archive merge-check

`/scaff:archive` 會拒絕封存 `standard` 或 `audited` feature 其分支尚未 merge 進 `main`。拒絕時印出分支名與 main ref,exit non-zero,feature 保持不動。

`tiny` tier 不觸發 merge-check。

**Escape hatch**:帶 `--allow-unmerged REASON` 可繞過。REASON 必填,省略會 exit non-zero 並印 usage 錯誤。理由會附到 STATUS Notes 並帶上日期與 role。

```sh
/scaff:archive --allow-unmerged "multi-PR split — PR #42 covers auth changes"
```

---

## Review capability

`/scaff:implement` 在 wave 收集與逐 task merge 之間內建 **inline 多軸 review**。每完成一個 task,三個 reviewer subagent 會平行跑(security / performance / style),各自從 `.claude/rules/reviewer/<axis>.md` 載入自己的 rubric、守在自己的軸向內、產出帶 severity tag 的 verdict。任何 `must` finding 封住該 wave merge;`should` / `advisory` findings 寫進 STATUS 做紀錄。

```sh
# 一次性多軸 review,產生時間戳記報告
/scaff:review <slug>                  # 三軸齊發
/scaff:review <slug> --axis security  # 單軸重審
```

報告寫到 `<feature-dir>/review-YYYYMMDD-HHMM.md`。此一次性指令不推進 STATUS,任何階段(implement、validate、archive、archive 之後)執行都安全。

`.claude/rules/reviewer/` 底下的 rubric 是 **agent 觸發** 的,不是 session 載入 — SessionStart hook 刻意略過此子目錄,rubric 內容只流到呼叫它們的 reviewer agent。

**Escape hatch**:`/scaff:implement --skip-inline-review` 完全繞過 inline reviewer dispatch。每次使用都會記到 STATUS Notes 供稽核。適用緊急情況,以及在自己實作 reviewer 能力的 feature 本身。

## `/scaff:validate` — 合併式驗證

`/scaff:validate <slug>` 以 **平行** 方式跑 `qa-tester`(動態軸 — 走每條 PRD acceptance criterion)與 `qa-analyst`(靜態軸 — PRD 對 diff 的 gap 分析),收集各自 verdict footer,以與 `/scaff:review` 相同的聚合 contract 合併為一個階段 verdict。產出:`08-validate.md`。

Verdict 值為 `PASS` / `NITS` / `BLOCK`。格式錯誤的 footer 一律 parse 為 BLOCK。

---

## `.claude/rules/` — session 級 guardrails

本 repo 附一個 SessionStart hook,會把 `.claude/rules/` 的摘要注入在此目錄下開啟的每個 Claude Code session。Rules 是 **硬性** 跨角色 guardrail(bash 3.2 可攜性、測試用 sandbox-HOME、user path 上禁用 `--force`、classify-before-mutate 等) — 不同於 `.claude/team-memory/` 的 per-role 軟性 craft advisory。

Hook 於 `settings.json` 接線:

```json
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":".claude/hooks/session-start.sh"}]}]}}
```

詳情(schema、severity 詞彙、撰寫檢查清單):見 [.claude/rules/README.md](.claude/rules/README.md)。

---

## `bin/scaff-*` helpers

`bin/` 下支撐本 workflow 的單一用途腳本。全部 bash 3.2 / BSD userland 可攜。

```sh
bin/scaff-seed <init|update|migrate>       # 專案 seed + 版本同步
bin/scaff-tier <slug>                      # 讀取 feature STATUS.md 的 tier: 欄位
bin/scaff-aggregate-verdicts <axes...>     # 聚合 per-axis verdict → PASS|NITS|BLOCK
bin/scaff-install-hook <event> <path>      # 冪等 settings.json hook 接線
bin/scaff-lint                             # pre-commit 語言偏好 linter
```

`bin/scaff-tier` 是讀取 feature `STATUS.md` 中 `tier:` 欄位的 **唯一** code path。所有腳本、agent、command 都透過此 helper — 沒有第二個 parse site。此規範靠 code review 把關。

`bin/scaff-aggregate-verdicts` 是 per-axis reviewer/validator verdict 的 **唯一** classifier。它從 scratch 目錄讀取 per-axis 輸出,在 stdout 第 1 行輸出 `PASS` / `NITS` / `BLOCK`;若出現 must-severity 的 security finding,則在第 2 行加上 `suggest-audited-upgrade: <task-id>`。

---

## `bin/claude-symlink` — 全域 symlink 管理工具

`bin/claude-symlink` 管理 `~/.claude/` 下的 symlinks,讓本 repo 的 Specaffold 內容能在這台機器上的每個 project 的 Claude Code session 使用。`install` / `uninstall` / `update` 三個子指令都可重跑;有衝突會回報並跳過(無 `--force` flag)。

### Managed set

- `~/.claude/agents/scaff` → `<repo>/.claude/agents/scaff`
- `~/.claude/commands/scaff` → `<repo>/.claude/commands/scaff`
- `~/.claude/hooks` → `<repo>/.claude/hooks`
- `~/.claude/skills/scaff-init` → `<repo>/.claude/skills/scaff-init`

`team-memory/**` **刻意不納入 managed set**。Repo-local memory(`<repo>/.claude/team-memory/`)留在 repo 範圍;全域 memory(`~/.claude/team-memory/`)是 per-user 的真實檔案,透過 `/scaff:promote` 顯式升級 — 不由 claude-symlink 從 repo 自動 symlink 過去。`update` 仍會走 `~/.claude/team-memory/` 把之前舊版留下的 owned symlink 清掉。

所有 symlink 都指向 **絕對路徑**,所以 `ls -l` 隨時可讀。repo 被移動會讓 symlink 失效 — 從新位置重跑 `install`(或 `update`)重建。

### 子指令

```sh
bin/claude-symlink install            # 首次安裝;冪等,可重跑
bin/claude-symlink uninstall          # 只移除本工具擁有的 symlinks
bin/claude-symlink update             # 補缺、修復 broken-ours、清除 owned orphans
bin/claude-symlink install --dry-run  # 預覽(任一子指令都支援)
```

支援平台:macOS 與 Linux(bash 3.2 / BSD userland 可攜)。Windows shell 會 exit 2 並印出訊息。

### 衝突處理

當管理路徑無法安全動作時,工具會跳過並回報一個 verb。任何跳過會讓 exit code 為 1;手動解除衝突後重跑。

| Verb | 意義 | 處理方式 |
|---|---|---|
| `skipped:real-file` | 目標位置有一般檔 | 檢查、備份、`rm`、重跑 |
| `skipped:real-dir` | 目標位置有一般目錄 | 檢查、備份、確認後 `rm -rf`、重跑 |
| `skipped:foreign-symlink` | 活 symlink 指向本 repo 以外(別的工具裝的) | 手動 `rm`、重跑 |
| `skipped:foreign-broken-symlink` | 斷 symlink 指向本 repo 以外 | 手動 `rm`、重跑 |
| `skipped:not-ours`(僅 `uninstall`) | 管理路徑上有本工具不擁有的 symlink | 視需要手動處理 |

### 注意事項:`team-memory/` 的 orphan-walk

`update` 會走過 `~/.claude/team-memory/`,清除本工具擁有的 orphan links。擁有權判斷規則單一:resolved 的 symlink 目標以 `<repo>/.claude/`(含結尾斜線)開頭。使用者手動在 `~/.claude/team-memory/` 下建立、且**剛好也指向本 repo** 的 symlink,與本工具建立的無法區分 — `update` 會當成 orphan 移除。請避免在 `~/.claude/team-memory/` 下手動放指向本 repo 的 symlink。

---

## Team memory

Specaffold 維護兩層 team memory,每次 agent 被喚起時都讀:

| Tier | 位置 | 用途 |
|---|---|---|
| Global | `~/.claude/team-memory/<role>/` | 跨所有專案通用的 lesson。真實檔案,每條一個 md。 |
| Local | `<repo>/.claude/team-memory/<role>/` | repo 專屬 lesson。隨 repo 納入版控、透過 git 分享。 |

Agent 讀取順序:**先 global、再 local**;local 同主題 entry 會靜默覆蓋 global 的。

`/scaff:archive` 會在 retrospective 階段問每個角色有無值得保存的心得;接受的條目就直接寫進對應 tier 的檔案。想把 local 條目升級到 global:`/scaff:promote <role>/<file>`。兩 tier 是**獨立**的 — `bin/claude-symlink install` 永遠不會自動把 repo-local memory 同步進 user-global 目錄。

完整撰寫協定:[.claude/team-memory/README.md](.claude/team-memory/README.md)。

---

## Verb vocabulary

`scaff-seed` 指令(`init`、`update`、`migrate`)的 stdout 只會出現下列 verb,每個受管理檔一行。任何 flow 都不會發出清單外的 verb;若未來新增 verb,必須先更新此表。

| Verb | 意義 | 處理方式 |
|---|---|---|
| `created` | 目的路徑原先缺件,已寫入新檔。 | 無 — 首次 init 預期。 |
| `already` | 目的檔與指定 ref 下 source 逐 byte 相同。 | 無。 |
| `replaced:drifted` | 目的檔與 source 不同、但與 manifest 中上版 ref 的 baseline 相同 — 以新內容覆蓋;覆寫前的內容存於 `<path>.bak`。 | 檢查 `.bak`,確認無誤後刪除。 |
| `skipped:user-modified` | 目的檔與 source 不同 **且** 與 baseline 不同 — 保留使用者編輯。 | 決定保留編輯(自行複製到 `.bak` 再重跑 `update`)或丟棄(從 baseline 還原再重跑)。 |
| `skipped:real-file-conflict` | 目的位置期望一般檔,但存在目錄、symlink 或非一般檔。 | 手動移除擋住的路徑再重跑。 |
| `skipped:foreign` | 目的位置不在受管理子樹內。 | 理論上不應發生;若觀察到請回報 bug。 |
| `skipped:unknown-state` | Classifier 產出未知 state(防禦性 wildcard arm)。 | 理論上不應發生;若觀察到請回報 bug — 代表 classifier/dispatcher 不一致。 |
| `would-create` / `would-replace:drifted` / `would-skip:already` / `would-skip:user-modified` / `would-skip:real-file-conflict` / `would-skip:foreign` / `would-skip:unknown` | 上述各 verb 的 `--dry-run` 預覽,無實際變更。 | 無。 |
