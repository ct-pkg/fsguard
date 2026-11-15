# PH-04 卡：包形态、平台边界与门禁

id: PH-04
status: in-progress
opened: 2026-11-15
spec-version: 1.10.0
version-minor: 4
roadmap: docs/planning/fsguard-roadmap.md

## 目标

把包形态、命名共存、POSIX 边界与门禁收口成可交付包：R-01 用**只 import `.m.ct` 的消费者单元**证明包形态成立；R-15 用 `a\b` 字面断言证明不建 Win32 分支；R-16 用 README 能力对照表把「不替代 `std::fs`」变成可核对项。R-03 的判据 3 依赖共享库机制，**本相不实施**，只写死标注与门禁。同时收掉前序 battle 已落地的 FSR-02/03/04 证据，`g7-lsan-record` 保持现状、不并入本相。

## 范围

**做什么**

- R-01：消费者单元只 import `fsguard::FsGuardOps`（`.m.ct`），在 `char *` 上调用四个方法并断言返回值；`walk` 必须实际回调到消费者的具名函数。
- R-15：MVP 只接受 `/`；`a\b` 按字面字符处理（不转换、不当作分隔符）；实现内无 Win32 分支。
- R-16：README 增加「能力对照表」，本包符号与 `std::fs` / `std::io` 一一对应；本包不暴露 `exists` / `readFile` / `writeFile` / `list`。
- R-03：**依赖共享库机制落地后才转门禁，期间保持未实施**。本相只把这句话写进卡与验收状态表，并由门禁核对标注存在；不写假通过的同名歧义用例。
- 保留已落地的 FSR-02/03/04：`known_bypass` 负例、手工清单、`g3-ph04`。

**不做什么**

- 不做 R-03 判据 3（两个 trait 同名 `walk` 的编译失败负例），不伪造限定调用成功的证据。
- 不改防护实现（D-012）；不改 `ct-pkg/std`；不动 `.ai-engineering`；不把 `g7-lsan-record` 并入 `all`。
- 不把命名空间目录上移到仓库根（`ct install` 的 `src/` 布局缺口只登记，不在本相改包布局）。

## 交付物清单

| # | 文件 | 说明 |
| --- | --- | --- |
| 1 | `test/fsguard/r18_known_bypass.ct` | FSR-02 软链替换、FSR-03 硬链接；断言绕过成立 |
| 2 | `docs/acceptance/fsguard-manual-checks.md` | FSR-04 的 Darwin 弱变体与 Linux `mount --bind` / userns 步骤 |
| 3 | `test/fsguard/r01_package.ct` | R-01 消费者单元，只 import `.m.ct`，四个方法 + 具名回调 |
| 4 | `test/fsguard/r15_posix.ct` | R-15 `a\b` 字面断言与 `/` 唯一分隔符 |
| 5 | `README.md` | 「## 能力对照表」：本包符号 ↔ std 符号 ↔ 归属 |
| 6 | `tools/check.sh` | `g3-ph04` 覆盖 r01 / r15 / r18 / all，并校验包形态、README 表、R-03 标注 |
| 7 | `docs/phases/PH-04/card.md` | 本卡 |

## 任务清单

| 任务 | 内容 | 验证 | 规模 | 回滚 |
| --- | --- | --- | --- | --- |
| T-01 | FSR-02/03 `known_bypass` 用例 | `bash tools/check.sh g3-ph04 r18` | S | `git revert <T-01 提交>` |
| T-02 | FSR-04 手工清单 | `bash tools/check.sh g3-ph04 all` | S | `git revert <T-02 提交>` |
| T-03 | `g3-ph04` 接入 `all`、PH-04 进 `g1-phase-card` | `bash tools/check.sh all` | S | `git revert <T-03 提交>` |
| T-04 | R-01 消费者测试（只 import `.m.ct`） | `bash tools/check.sh g3-ph04 r01` | M | `git revert <T-04 提交>` |
| T-05 | R-15 `a\b` 字面断言 | `bash tools/check.sh g3-ph04 r15` | S | `git revert <T-05 提交>` |
| T-06 | R-16 README 能力对照表 | `bash tools/check.sh g3-ph04 all` | S | `git revert <T-06 提交>` |
| T-07 | R-03 未实施标注 + 门禁核对 | `bash tools/check.sh g3-ph04 all` | S | `git revert <T-07 提交>` |

## 退出判据

| # | 判据 | 验证 | 期望 |
| --- | --- | --- | --- |
| E-1 | R-01 消费者只 import `fsguard::FsGuardOps`，四个方法各自断言，`walk` 回调次数 ≥1 且看到文件 | `bash tools/check.sh g3-ph04 r01` | rc=0，4 checks |
| E-2 | R-01 包内不存在 `pub trait … for char *`，`.h.ct` / `.m.ct` 无 `#define`（prologue 除外） | `bash tools/check.sh g3-ph04 all` | rc=0 |
| E-3 | R-15 `a\b` 原样保留：`normalize_to` 不改写、`is_under` 不把 `\` 当分隔符；`src` 无 Win32 分支 | `bash tools/check.sh g3-ph04 r15` | rc=0 |
| E-4 | R-16 README「能力对照表」覆盖本包全部公开方法与 std 四个原语；本包不暴露 `exists` / `readFile` / `writeFile` / `list` | `bash tools/check.sh g3-ph04 all` | rc=0 |
| E-5 | R-03 卡与状态表含「依赖共享库机制落地后才转门禁，期间保持未实施」 | `bash tools/check.sh g3-ph04 all` | rc=0 |
| E-6 | FSR-02/03 负例绿；硬链接不支持时 SKIP 不算通过 | `bash tools/check.sh g3-ph04 r18` | rc=0 或 rc=3 + `skip:` |
| E-7 | FSR-04 手工清单含 `hdiutil`、`mount --bind`、`weaker variant`、`userns` | `bash tools/check.sh g3-ph04 all` | rc=0 |
| E-8 | 全量门禁 | `bash tools/check.sh all` | rc=0（`g7-lsan-record` 单独跑，仍红） |
| E-9 | 任务清单每项可独立验收（6.6 T-6） | 人工核对 | 是 |

## 依赖

- D-011（不依赖 std、不拆 path 包）、D-012（词法策略层，非安全边界）。
- `docs/reviews/fsguard-fsr-battle.md`（B-001）与 §9 落地记录。
- `docs/reviews/fsguard-std-overlap.md` §3（符号级对照）作为 README 能力对照表的事实来源。
- R-03 判据 3 的阻塞项：两个 `map trait` 同名方法的限定调用，依赖共享库机制落地。

## 已知风险

- R-01 的消费者测试会连带编译 `FsGuard.c`（`.m.ct` 自身 import 了 `.h.ct`），因此它证明的是「消费者不需要 import `.h.ct`」，不是「包只有一个单元」。
- `known_bypass` 固化的是「已知绕过」，不是功能承诺；用例名、注释与 D-012 三处同时否定，失败即提示行为变化需重开 D-012。
- 硬链接在不支持的文件系统上 SKIP，SKIP 不算通过；CI 需用 ext4/tmpfs/APFS。
- FSR-04 平台差异大（macOS 无 nullfs、Linux 需 root/userns），只写手工清单，不进 CI。
- R-16 判据 1（std 仓 diff 为空）本仓无法自证，只能核对「零引用」：`ct.pkg` 无 `dep`、`src` 不 include std 路径；std 侧以只读 `git status` 为准。
