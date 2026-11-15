# PH-04 卡：包形态、平台边界与门禁（按依赖切两半）

id: PH-04
status: in-progress
opened: 2026-11-15
spec-version: 1.10.0
version-minor: 4
roadmap: docs/planning/fsguard-roadmap.md

## 目标

把不依赖外部条件的工作先做完：文档口径一次改齐、R-15 的 `a\b` 字面断言、R-16 的 README 能力对照表、FSR-02/03 已知绕过负例进普通门禁。依赖包机制、编译器能力或 Linux 的四项（R-01 判据 2/3、R-03 判据 1/2/3、R-02 限定名、R-17 LSan 记录）**只写进本卡并挂起**，不伪造通过证据。

## 范围

**前半（现在做，不依赖外部条件）**

1. 文档口径六处一次更正：`fsguard-status.md` 的 D-001…D-012、R-02 的 ct 版本号、roadmap 的 13/4 → 15/2、PH-01/02/03 三张卡的 `status`、FSR-05/06 标已收口、`fsguard-std-overlap.md` §6 的 S-2 与 S-6 合并。
2. R-15 判据 3：`a\b` 按字面字符处理的运行断言（`g3-ph04 r15`）。
3. R-16 判据 3：README「能力对照表」与实现方法一一对应，并加门禁 grep（`g3-ph04 all`）。
4. FSR-02/03 两条已知绕过负例进普通门禁，**断言「绕过成立」**（不是断言被拒），用例名带 `known_bypass`、断言落到根外内容本身、文件头写明不是安全保证；FSR-04 只写文档 + 手工清单，不进 CI。

**后半（现在只写进卡，挂起）**

| 项 | 挂起条件（逐条） |
| --- | --- |
| R-01 判据 2/3：消费者只 import `.m.ct` 的消费者测试 | **等 `ns-root`/包机制能标准安装**：`ct install` 目前只打印 `-I vendor/fsguard`，而单元在 `src/fsguard/`，消费者实测 `cannot resolve import 'fsguard/FsGuard'`；包布局或安装器修好后，把消费者测试接进 `g3-ph04` |
| R-03 判据 1/2/3：`std::fs` / `std::str` 共存与同名 `walk` 的歧义/限定调用 | **依赖共享库机制落地后才转门禁，期间保持未实施**：需要两个 `map trait` 在同一单元映射同名方法并支持 `FsGuardOps::walk(...)` 限定调用；当前不写假通过的负例 |
| R-02 限定名断言：`FsErrCode::FS_ERR_*` | **等 CT 支持 `Type::Member`**：ct 0.53.0 仍报 `qualified type names are not supported`；升级后复跑 `test/fsguard/r02_errors.ct` 的限定名用例 |
| R-17 Linux LSan 记录回填 | **等一台 Linux**：`ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` 后按模板回填 `docs/reviews/fsguard-lsan-linux.md`；`g7-lsan-record` 保持红 |

**不做什么**

- 不实施后半四项，不写占位记录、不写跳过的消费者测试。
- 不改防护实现（D-012）；不改 `ct-pkg/std`；不动 `.ai-engineering`；不把 `g7-lsan-record` 并入 `all`。
- 不把命名空间目录上移到仓库根（`ct install` 的 `src/` 布局缺口只登记）。

## 交付物清单

| # | 文件 | 说明 |
| --- | --- | --- |
| 1 | `docs/acceptance/fsguard-status.md` 等六处文档 | 口径更正 |
| 2 | `test/fsguard/r15_posix.ct` | R-15 `a\b` 字面断言 |
| 3 | `README.md` | 「## 能力对照表」 |
| 4 | `test/fsguard/r18_known_bypass.ct` | FSR-02 软链替换、FSR-03 硬链接；断言绕过成立 |
| 5 | `docs/acceptance/fsguard-manual-checks.md` | FSR-04 Darwin 弱变体与 Linux `mount --bind` / userns 步骤 |
| 6 | `tools/check.sh` | `g3-ph04`（r15/r18/all）+ `g4-static` 的文档口径核对 |
| 7 | `docs/phases/PH-04/card.md` | 本卡 |

## 任务清单

| 任务 | 内容 | 验证 | 规模 | 回滚 |
| --- | --- | --- | --- | --- |
| T-01 | 六处文档口径更正 | `bash tools/check.sh g4-static` | S | `git revert <T-01 提交>` |
| T-02 | R-15 `a\b` 字面断言 | `bash tools/check.sh g3-ph04 r15` | S | `git revert <T-02 提交>` |
| T-03 | R-16 README 能力对照表 + 门禁 grep | `bash tools/check.sh g3-ph04 all` | S | `git revert <T-03 提交>` |
| T-04 | FSR-02/03 `known_bypass` 负例 | `bash tools/check.sh g3-ph04 r18` | S | `git revert <T-04 提交>` |
| T-05 | FSR-04 手工清单 | `bash tools/check.sh g3-ph04 all` | S | `git revert <T-05 提交>` |
| T-06 | 卡面挂起项与门禁收口 | `bash tools/check.sh all` | S | `git revert <T-06 提交>` |

## 退出判据

| # | 判据 | 验证 | 期望 |
| --- | --- | --- | --- |
| E-1 | 六处文档口径逐项命中：status 标题 `D-001…D-012`、无 `0.44.1`、roadmap `15 条可验收、2 条部分可验收`、三卡 `status: closed`、FSR-05/06 `已收口`、overlap 无 `S-6` 表格行 | `bash tools/check.sh g4-static` | rc=0 |
| E-2 | R-15：`a\b` 原样保留、`.` 不在反斜杠段折叠、`\` 不作段边界、驱动器形式不解析；`src` 无 Win32 分支 | `bash tools/check.sh g3-ph04 r15` | rc=0，7 checks |
| E-3 | R-16：README「能力对照表」覆盖本包符号与 std 四原语；trait 恰为四名；不暴露 `exists`/`readFile`/`writeFile`/`list` | `bash tools/check.sh g3-ph04 all` | rc=0 |
| E-4 | FSR-02/03：`check` 通过后换软链，读到根外哨兵；硬链接读根外 inode；失败提示要求重开 D-012 | `bash tools/check.sh g3-ph04 r18` | rc=0；不支持硬链接时 rc=3 + `skip:`，不算通过 |
| E-5 | FSR-04 手工清单含 `hdiutil`、`mount --bind`、`weaker variant`、`userns` | `bash tools/check.sh g3-ph04 all` | rc=0 |
| E-6 | 前半全绿 | `bash tools/check.sh all` | rc=0（`g7-leak` 在 Darwin SKIP；`g7-lsan-record` 单独跑，仍红） |
| E-7 | 后半四项仍挂起，卡内四条挂起条件齐全 | `bash tools/check.sh g3-ph04 all` | rc=0，卡内含 `ns-root`、`Type::Member`、`一台 Linux`、`PH-04 不得收口` |
| E-8 | **前半全绿 + 后半仍挂起时 PH-04 不得收口** | 人工核对 | 卡状态保持 `in-progress`，不得改 `closed` |
| E-9 | 任务清单每项可独立验收（6.6 T-6） | 人工核对 | 是 |

## 依赖

- D-011（不依赖 std、不拆 path 包）、D-012（词法策略层，非安全边界）。
- `docs/reviews/fsguard-fsr-battle.md`（B-001）与 §9 落地记录。
- `docs/reviews/fsguard-std-overlap.md` §3（符号级对照）作为 README 能力对照表的事实来源。
- 后半四项的外部依赖见「范围」表的挂起条件。

## 已知风险

- `known_bypass` 固化的是「已知绕过」，不是功能承诺；用例名、注释与 D-012 三处同时否定，失败即提示行为变化需重开 D-012。
- 硬链接在不支持的文件系统上 SKIP，SKIP 不算通过；CI 需用 ext4/tmpfs/APFS。
- FSR-04 平台差异大（macOS 无 nullfs、Linux 需 root/userns），只写手工清单，不进 CI。
- R-16 判据 1（std 仓 diff 为空）本仓无法自证，只能核对「零引用」；std 侧以只读 `git status` 为准。
- 后半四项没有实现，因此本卡即使前半全绿也不能收口；`g7-lsan-record` 的红色是挂起信号，不是回归。
