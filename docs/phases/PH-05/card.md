# PH-05 卡：收口三项挂起验收（消费者、限定名、LSan）

id: PH-05
status: closed
opened: 2026-11-17
closed: 2026-11-17
spec-version: 1.10.0
version-minor: 5
roadmap: docs/planning/fsguard-roadmap.md

## 目标

把 PH-04 移出的 R-01 判据 2/3、R-02 判据 2 与 PH-04 记环境缺口的 R-17 判据 5 收成可核对的运行证据，使 17 条 R 全部有结论、roadmap 不再有未完成 phase。

## 范围

**做什么**

- R-01 判据 2/3：消费者单元只 import 本包单元；对 `char *` 调 `normalize_to` / `is_under` / `read_chunk` / `walk` 并分别断言返回值；`FsWalkCb` 从 `.h.ct` 可见、具名回调实际被调用。
- R-02 判据 2：裸名与限定名 `FsErrCode::FS_ERR_*` 分别取值并断言（本机 `ct v0.62.0` 已支持）。
- R-17 判据 5：在 Linux 主机上跑 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`，把 host、命令、原始输出回填 `docs/reviews/fsguard-lsan-linux.md`。
- 收口：状态表、roadmap、CHANGELOG、版本 0.5.0、annotated tag `v0.5.0`。

**不做什么**

- 不改 `docs/requirements.md` 与 `docs/design.md` 正文，不改三条判据原文。
- 不新增 API、不改 `src/fsguard` 行为、不补 std 建议、不改 `ct-pkg/std`。
- 不处理 FSG-02（`ct install` 不识别 `.m.ct`，上游 open）；消费者验收按 D-015 走 `ct build` + 运行，不看 `ct install` rc。
- 不迁移规范 pin（`AGENTS.md` 仍按 1.10.0 执行；主规范 1.15.0 的 G9 落后单独登记，不夹进本相）。
- 不推分支、不做对外发布；tag 的远端推送受 6.5 分支推送约束，见「已知风险」K-3。

## 交付物清单

| # | 路径 | 内容 |
| --- | --- | --- |
| 1 | `test/consumer/consumer.ct` | 消费者夹具：只 import 本包，四方法 + 回调断言 |
| 2 | `test/fsguard/r02_errors.ct` | R-02 判据 2：裸名 + 限定名断言 |
| 3 | `tools/check.sh` | `g3-ph05`、`g1-phase-card` 支持 PH-05、`g4-static` 计数更新、`all` 接入 |
| 4 | `docs/reviews/fsguard-lsan-linux.md` | Linux LSan 实测记录（host / 命令 / 原始输出） |
| 5 | `docs/reviews/fsguard-ph05-evidence.md` | 红绿原始输出与任务对照 |
| 6 | `docs/acceptance/fsguard-status.md`、`docs/planning/fsguard-roadmap.md` | R 状态与总退出更新 |
| 7 | `AGENTS.md` 0.1 | 版本落点、Issue 台账、门禁入口、决策记录更新 |
| 8 | `CHANGELOG.md`、`ct.pkg` | 0.5.0 收口记录与版本 |
| 9 | `docs/phases/PH-05/card.md` | 本卡 |

## 任务清单

| ID | 交付物 | 验收命令 | effort | 回滚 |
| --- | --- | --- | --- | --- |
| T-01 | `test/consumer/consumer.ct` + `g3-ph05` | `bash tools/check.sh g3-ph05 consumer` | M | `git revert <T-01 实现提交>` |
| T-02 | `test/fsguard/r02_errors.ct` 限定名断言 | `bash tools/check.sh g3-ph01 r02` | S | `git revert <T-02 实现提交>` |
| T-03 | `docs/reviews/fsguard-lsan-linux.md` + `g7-lsan-record` 转绿 | `bash tools/check.sh g7-lsan-record` | M | `git revert <T-03 实现提交>`；记录可删除后重跑门禁 |
| T-04 | 收口记录、版本 0.5.0、tag `v0.5.0` | `bash tools/check.sh all` 且 `bash tools/check.sh g7-lsan-record` | S | `git revert <T-04 收口提交>`；tag 删除需用户指令 |

任务清单每项可独立验收（6.6 T-6）：每条任务的验收命令只验本任务交付物，不借「整相全绿」；一项任务不同时覆盖两条退出判据（6.6 T-5）。T-04 只对「收口记录与版本/tag」负责，`all` 是相位级复核，不构成 T-04 的第二条交付。

## 退出判据

| # | 判据 | 命令 / 锚点 | 二值结果 |
| --- | --- | --- | --- |
| E-1 | R-01 判据 2/3：消费者只 import 本包，四方法返回值与回调调用次数均断言 | `bash tools/check.sh g3-ph05 consumer` | rc=0；输出含 `consumer` 与 `all checks passed` |
| E-2 | R-02 判据 2：裸名与限定名分别取值并断言 | `bash tools/check.sh g3-ph01 r02` | rc=0；用例输出含 `qualified` |
| E-3 | R-17 判据 5：Linux LSan 原始记录 | `bash tools/check.sh g7-lsan-record` | rc=0；记录含 `host: Linux …`、确切命令、`PASS: g7-leak: Linux ASan+LSan caught the leak` |
| E-4 | 本相全量：既有门禁与新门禁一起绿 | `bash tools/check.sh all` | rc=0 |
| E-5 | 任务清单每项可独立验收（6.6 T-6）：卡片字段齐全，每条任务有交付物/验收命令/effort/回滚 | `bash tools/check.sh g1-phase-card PH-05` | rc=0 |
| E-6 | 收口：`ct.pkg#version = 0.5.0`、CHANGELOG 有 0.5.0、annotated tag `v0.5.0` 指向收口提交 | `git cat-file -t v0.5.0` 且 `git rev-parse v0.5.0^{commit}` = 收口提交；`grep -x 'version = 0.5.0' ct.pkg` | 三项全中 |
| E-7 | 判据原文未被本相修改 | `git diff --exit-code f1641a8 -- docs/requirements.md` | rc=0（无输出）；基线取 PH-05 实施前的 `f1641a8`（`v0.4.0` 之后还有一条 R-03 执行前提提交，不属 PH-05） |

## 三条边界

**B-1 限定名依赖工具链版本，不依赖本相代码。** 触发条件仍是 D-013 写的 `ct >= v0.59.0`；本机为 `ct v0.62.0`，探针 `FsErrCode::FS_ERR_IO` 返回 8、`FS_ERR_OUT_OF_BOUNDS` 返回 3。若换回旧工具链，E-2 转红，本相停在 T-02，不改判据。

**B-2 Linux LSan 用真实 Linux 主机，不用 Darwin SKIP 顶替。** 本次用 Lima `vz` 启动 Debian 12（`Linux 6.1.0-54-cloud-arm64 aarch64`，gcc 12.2.0），只把 `tools/check.sh` 与 `tools/fixtures/` 复制进 guest 的 `/tmp/fsg-lsan` 后执行。记录写 host、命令、原始输出；Darwin 的 `SKIP` 仍不是泄漏结论。

**B-3 消费者仍要显式 C 头包含根。** `ct v0.62.0` 未把 `ns-root` 传给 C 编译器，消费者验收带 `--cflags "-Isrc"`；这是 D-013 K-3 的已知缺口，不构成本相失败，也不 pretending 已由 lock 自动补齐。import 侧只走包命名空间，不手写包内相对路径。

## 依赖

- PH-01…PH-04 已收口；D-013（移出与触发条件）、D-014（std 依赖口径）、D-015（`ct install` 缺陷处置）。
- `ct v0.62.0`（`~/.local/bin/ct`）；Linux 主机或可启动的 Linux 虚拟机。
- 打包 1.1 已提交 `publisher` / `ns-root`（`ct pkg check` 四条判据全过）。
- `docs/reviews/fsguard-phase-plan-review.md` 的 P-1…P-6 已处置。

## 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| K-1 | `ct` 不在 PATH 或版本低于 v0.59.0 | `g3-ph05`/`g3-ph01` 报 `ct not found`；限定名用例报 `qualified type names are not supported` | 显式 `CT=~/.local/bin/ct`；E-2 转红，停在 T-02，不改判据 |
| K-2 | Linux 记录不可复现 | `g7-lsan-record` 找不到 host/命令/PASS | 记录必须含 guest 的 `uname -srm`、gcc 版本、复制范围与日期；不用占位符 |
| K-3 | tag 无法推送 | `git branch -r --contains <收口提交>` 为空（分支未推） | 只创建本地 annotated tag 并记录原因；分支推送与 tag 远端推送等用户显式指令（6.5、6.7 V-7） |
| K-4 | 消费者夹具依赖 `/tmp` 可写 | `g3-ph05` 报 fixture 创建失败 | 夹具运行时生成并在退出前删除；失败即门禁红，不跳过 |
| K-5 | 收口时误改判据原文 | `git diff v0.4.0 -- docs/requirements.md` 非空 | E-7 转红；回退该文件，只改状态表与 roadmap |

## 收口记录（完成时填写）

| 项 | 结果 |
| --- | --- |
| E-1 | 绿：`g3-ph05 consumer` 16 checks，见 `docs/reviews/fsguard-ph05-evidence.md` §1 |
| E-2 | 绿：`g3-ph01 r02` 11 qualified + 22 checks，见 §2 |
| E-3 | 绿：Linux `PASS: g7-leak: Linux ASan+LSan caught the leak`；`g7-lsan-record` rc=0，见 §3 |
| E-4 | 绿：`bash tools/check.sh all` rc=0，见 §4 |
| E-5 | 绿：`g1-phase-card PH-05` rc=0（4 tasks，字段齐全） |
| E-6 | 绿：`ct.pkg` 0.5.0、CHANGELOG 0.5.0、annotated `v0.5.0` 指向收口提交 |
| E-7 | 绿：`git diff --exit-code f1641a8 -- docs/requirements.md` 无输出 |
| R-01 | 可验收（判据 1/4 + 2/3） |
| R-02 | 可验收（判据 2 限定名已补） |
| R-17 | 可验收（判据 5 Linux 记录已回填） |
| 未消解清单 | 1 条（C-6，见 6.7；本相未新增偏离） |
