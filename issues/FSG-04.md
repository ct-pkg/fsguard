# FSG-04 规范 pin 落后：`AGENTS.md` 是 1.10.0，主规范已是 1.15.0

id: FSG-04
status: fixed
opened: 2026-11-17
fixed: 2026-11-17（AGENTS 块与 docs/spec 刷新到 1.15.0）
phase: cross-cutting
severity: major
rule: G9（规范锚定）、11.5 L-1（一版一同步）
anchor: `AGENTS.md:6`（spec:begin 块头）；`docs/spec/ai-coding-workflow.md:5`
evidence: 见 §复现（`sync-agents.sh --check` 原始输出）

## 现象

项目生成块与全文副本仍钉在 `spec-version 1.10.0`，主规范已到 `1.15.0`。
`sync-agents.sh --check` 报块头与主规范不一致。

## 复现

```console
$ cd /Users/samxx/trae-ws/ct-fsguard
$ bash /Users/samxx/trae-ws/.ai-engineering/bin/sync-agents.sh --check AGENTS.md
FAIL 块头与主规范不一致：AGENTS.md
  期望：<!-- spec:begin version=1.15.0 sha256=1619a8c37c46403c0eb7a4f60465747477fbcf4842c3a71c28f542f5d3dd77f9 -->
  实际：<!-- spec:begin version=1.10.0 sha256=e3905e9bf8637a1e486a8498ed653628ec3c50be53298c60e609efc3b6a33caf -->
RC=1
```

## 影响

- G9 的「`spec-version` 不落后」不满足；项目仍按 1.10.0 的摘录执行，主规范 1.15.0 新增的
  §9.8 目录边界、§9.10、D0-20 追加式决策等条款没有进入本项目生成块。
- 这是**跨切面治理项**，不属于 PH-05 的退出判据；PH-05 只在 1.10.0 口径下完成 R-01/R-02/R-17 的收口，
  不夹带规范迁移。
- 不能手改块内字符；必须用 `sync-agents.sh --write` 刷新块与 `docs/spec` 副本。

## 处置（2026-11-17）

- 已按 11.5 L-6 执行：用主规范来源的 `sync-agents.sh --write AGENTS.md` 刷新
  `AGENTS.md` 块与 `docs/spec/ai-coding-workflow.md`，块头为
  `version=1.15.0 sha256=1619a8c37c46403c0eb7a4f60465747477fbcf4842c3a71c28f542f5d3dd77f9`。
- `bash /Users/samxx/trae-ws/.ai-engineering/bin/sync-agents.sh --check AGENTS.md` rc=0：
  `ok docs/spec/ai-coding-workflow.md（全文副本 sha256=1619…）`、`ok AGENTS.md（version=1.15.0）`。
- 该提交路径集合只含 `AGENTS.md` 与 `docs/spec/ai-coding-workflow.md`，符合 11.5 L-4。
- 迁移时已核对 1.15.0 的新增条款：§9.8 目录边界、§9.10 跨项目反馈、D0-20 追加式决策；
  本仓没有新增跨项目写入。
- 关闭条件：REQ 按 11.5 L-6 的发布流程，用主规范来源的 `sync-agents.sh --write AGENTS.md` 刷新
  `AGENTS.md` 块与 `docs/spec/ai-coding-workflow.md`，`sync-agents.sh --check AGENTS.md` rc=0；
  该提交路径集合只含 `AGENTS.md` 与 `docs/spec/ai-coding-workflow.md`（11.5 L-4）。
- 迁移时逐条核对 1.10.0→1.15.0 的新增条款（尤其 §9.8 目录边界、§9.10、D0-20），
  不把「刷新成功」当作「已合规」。

## 关闭条件

`sync-agents.sh --check AGENTS.md` rc=0，块头 `version=1.15.0`、`sha256` 等于主规范实算值，
`docs/spec/ai-coding-workflow.md` 与主规范逐字相同；`G9` 通过。

## 备注

该条与 PH-05 的 `docs/reviews/fsguard-phase-plan-review.md` P-7 对应；P-7 明确写「不在本 phase 改」。
