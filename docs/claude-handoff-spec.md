# Spec:Claude Code Context Handoff 自動化

> 角色分工:Opus = 架構師(本文件),Sonnet = 實做者。
> 本 spec 描述行為契約與接線位置,實作細節(完整 bash)由 Sonnet 完成。

## 目標

Context 接近上限前,在**乾淨的任務邊界**強制模型把工作狀態寫進 `HANDOFF.md`;
使用者 `/clear` 後由 SessionStart hook 自動把它灌回新 context。
平時模型增量維護 `HANDOFF.md`,Stop hook 只是最後防線。

避免的失敗模式:等 context 變大才寫 handoff = 讓一個已被 context 壓到降智的模型去寫總結。
所以品質來源是「平時增量維護」,Stop hook 只負責 flush + 兜底。

## 架構總覽

```
[平時] 模型在任務節點增量更新 $cwd/HANDOFF.md      ← 靠 CLAUDE.md 紀律
[防線] Stop hook  → 算 token,超門檻且 HANDOFF 不新鮮 → block 逼模型寫
[回收] SessionStart(source=clear/compact) → 把 HANDOFF.md 當 additionalContext 注入
```

## 關鍵約束(實作前必讀)

1. `~/.claude/settings.json` 是 home-manager 生成的 nix store symlink,**不能直接編輯**。
   所有 hook 設定改在 `~/dotfiles.nixos/hosts/shared/home.nix` 的
   `home.file.".claude/settings.json"`(約 L517),改完 `home-manager switch`。
2. 新 hook 邏輯較複雜(解析 transcript token),**拆成獨立 script 用 `home.file` 宣告**,
   settings.json 只引用 `bash /home/richard/.claude/hooks/xxx.sh`。不要 inline 塞 JSON。
3. hook 執行環境 PATH 不保證,script 內所有外部工具用 nix store 絕對路徑(`${pkgs.jq}/bin/jq`)。

---

## 元件 1:Stop hook — `~/.claude/hooks/handoff-guard.sh`

**輸入**(stdin JSON):`transcript_path`、`cwd`、`stop_hook_active`(bool)。

**邏輯契約(依序):**

1. **`stop_hook_active == true` → 立刻 `exit 0`。**
   P0 死迴圈防護:上一輪的停止已經是被本 hook 逼出來的,這輪必須放行,否則模型永遠停不下來。
2. 讀 `$cwd/HANDOFF.md` 的 mtime;距今 < 90 秒 → `exit 0`(已新鮮,別吵)。
3. 解析 `transcript_path`(JSONL):取**最後一筆 assistant message 的 `message.usage`**,
   token = `input_tokens + cache_read_input_tokens + cache_creation_input_tokens + output_tokens`。
   這是真實 context 佔用,**不要用檔案大小估**。
4. token < 門檻(預設 `120000`,可由環境變數 `HANDOFF_TOKEN_THRESHOLD` 覆寫)→ `exit 0`。
5. 否則 stdout 輸出以下 JSON 並 `exit 0`:
   ```json
   {"decision":"block","reason":"⚠️ Context 已達 <N> tokens。結束前請寫/更新 ./HANDOFF.md,需涵蓋:① 當前任務與目標 ② 已修改檔案清單 ③ 未完成 TODO ④ 關鍵決策與踩過的坑 ⑤ 下一步具體動作。完成後即可正常結束。"}
   ```

**邊界處理:** `usage` 解析失敗(空 transcript / 格式異常 / 最後一筆是工具結果無 usage)
→ 視為未超標 `exit 0`,**絕不阻斷正常結束**。
取最後一筆用 `tail` 反向掃 JSONL,跳過沒有 `.message.usage` 的行。

---

## 元件 2:SessionStart hook — `~/.claude/hooks/handoff-recall.sh`

**輸入**(stdin JSON):`source`(`startup`/`resume`/`clear`/`compact`)、`cwd`。

**契約:**

1. `source` 不是 `clear` 也不是 `compact` → `exit 0`。
2. `$cwd/HANDOFF.md` 不存在 → `exit 0`。
3. 存在 → stdout 輸出:
   ```json
   {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<HANDOFF.md 全文>"}}
   ```
   用 jq `--rawfile` 把檔案內容安全塞進 JSON,**不要手動 escape**。

---

## 元件 3:nix 接線(`hosts/shared/home.nix`)

兩支 script 宣告:

```nix
home.file.".claude/hooks/handoff-guard.sh" = {
  executable = true;
  text = ''
    #!/usr/bin/env bash
    # ... 見元件 1 契約;jq 用 ${pkgs.jq}/bin/jq
  '';
};
home.file.".claude/hooks/handoff-recall.sh" = {
  executable = true;
  text = ''
    #!/usr/bin/env bash
    # ... 見元件 2 契約
  '';
};
```

在現有 `hooks` attr(L529)內**新增**(不要動 PostToolUse formatter / UserPromptSubmit 截圖提醒):

```nix
Stop = [{
  hooks = [{ type = "command"; command = "bash /home/richard/.claude/hooks/handoff-guard.sh"; }];
}];
SessionStart = [{
  matcher = "clear|compact";
  hooks = [{ type = "command"; command = "bash /home/richard/.claude/hooks/handoff-recall.sh"; }];
}];
```

---

## 元件 4:增量維護紀律(品質來源,勿漏)

在目標專案的 `CLAUDE.md` 加一段(或寫成一條 `feedback` memory):

> 完成每個可交付的任務節點後,順手更新 repo 根目錄 `HANDOFF.md`:
> 當前任務 / 已改檔 / 待辦 / 關鍵決策 / 下一步。保持精簡、覆蓋而非追加。

並把 `HANDOFF.md` 加進該專案 `.gitignore`(ephemeral 工作狀態,不進版控)。

---

## 驗收

1. `home-manager switch` 後 `cat ~/.claude/settings.json` 能看到 `Stop` 與 `SessionStart`。
2. 構造假 transcript(usage 總和 > 120k)餵 `handoff-guard.sh` → 輸出 `decision:block`;
   同 input 加 `"stop_hook_active":true` 再餵一次 → `exit 0` 無輸出(**死迴圈防護必過**)。
3. 放一個 `HANDOFF.md`,用 `{"source":"clear","cwd":"…"}` 餵 `handoff-recall.sh`
   → 吐出含全文的 `additionalContext`。

## 踩雷提醒

- **P0** `stop_hook_active` 防迴圈:驗收 2 一定要過。
- token 來源是 `message.usage`,不是檔案大小。
- 所有失敗路徑都 `exit 0`,hook 絕不能把使用者卡在「停不下來」。
- script 內外部工具一律 nix store 絕對路徑。
