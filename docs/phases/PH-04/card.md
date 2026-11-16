# PH-04 卡：包形态、平台边界与门禁（按依赖切两半）

id: PH-04
status: in-progress
opened: 2026-11-15
spec-version: 1.10.0
version-minor: 4
roadmap: docs/planning/fsguard-roadmap.md

## 目标

把不依赖外部条件的工作先做完：文档口径一次改齐、R-15 的 `a\b` 字面断言、R-16 的 README 能力对照表、FSR-02/03 已知绕过负例进普通门禁。R-03 判据 1/2/3 已按 D-014 落地（依赖 `std@0.3.2`，构建与门禁走包根头路径，不 vendor）；R-17 LSan 记录仍等 Linux 环境。R-01 判据 2/3 与 R-02 限定名按 D-013（B-002 battle）移出本相，去向与触发条件见「裁定记录」，不伪造通过证据。

## 范围

**前半（现在做，不依赖外部条件）**

1. 文档口径六处一次更正：`fsguard-status.md` 的 D-001…D-012、R-02 的 ct 版本号、roadmap 的 13/4 → 15/2、PH-01/02/03 三张卡的 `status`、FSR-05/06 标已收口、`fsguard-std-overlap.md` §6 的 S-2 与 S-6 合并。
2. R-15 判据 3：`a\b` 按字面字符处理的运行断言（`g3-ph04 r15`）。
3. R-16 判据 3：README「能力对照表」与实现方法一一对应，并加门禁 grep（`g3-ph04 all`）。
4. FSR-02/03 两条已知绕过负例进普通门禁，**断言「绕过成立」**（不是断言被拒），用例名带 `known_bypass`、断言落到根外内容本身、文件头写明不是安全保证；FSR-04 只写文档 + 手工清单，不进 CI。

**后半（R-17 挂起；R-01 2/3、R-02 已按 D-013 移出；R-03 已按 D-014 落地）**

| 项 | 状态与条件（逐条） |
| --- | --- |
| R-01 判据 2/3：消费者只 import `.m.ct` 的消费者测试 | **已移出 PH-04（D-013）**：上游 `ns-root`/包机制已交付（v0.55.0 定根、v0.58.0 读 lock；PKG-2 已解决），本机 v0.58.0 实测 `ct install` 打印 `-I …/src`、`ct build` 不再报 `cannot resolve import`；本仓 `publisher`/`ns-root` 已提交（打包 1.1，`ct pkg check` 四条判据全过），剩余消费者夹具，转 PH-05 首任务，判据原文不动 |
| R-03 判据 1/2/3：`std::fs` / `std::str` 共存与同名 `walk` 的歧义/限定调用 | **已落地（D-014，B-003）**：`ct.pkg` 声明 `dep = std@0.3.2`、`ct.lock` 提交；用例 `r03_coexist`（判据 1/2）、`r03_qualified` / `r03_ambiguous`（判据 3），门禁 `g3-ph04 r03` 走 `ct build` + 运行；`ct install` 的 `.m.ct` 缺陷登记 FSG-02 |
| R-02 限定名断言：`FsErrCode::FS_ERR_*` | **已移出 PH-04（D-013）**：上游 `Type::Member` 仍缺（LANG-15 open，排 PH-57 / v0.59.0；本机 v0.58.0 实测报 `qualified type names are not supported`）；转 PH-05，触发 `ct >= v0.59.0` 后复跑限定名用例 |
| R-17 Linux LSan 记录回填 | **等一台 Linux**：`ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` 后按模板回填 `docs/reviews/fsguard-lsan-linux.md`；`g7-lsan-record` 保持红 |

**不做什么**

- 不实施 R-17 挂起项（Linux 记录未回填前不伪造）；R-01 判据 2/3 与 R-02 按 D-013 移出本相，不在本相实施，也不写占位记录或跳过用例。
- 不改防护实现（D-012）；不改 `ct-pkg/std`；不动 `.ai-engineering`；不把 `g7-lsan-record` 并入 `all`。
- 不 vendor 第三方源码：std 只通过 `dep` + `ct.lock` 引入（D-014）。
- 不把命名空间目录上移到仓库根（`src/` 布局由 `ns-root` 满足）。

## 交付物清单

| # | 文件 | 说明 |
| --- | --- | --- |
| 1 | `docs/acceptance/fsguard-status.md` 等六处文档 | 口径更正 |
| 2 | `test/fsguard/r15_posix.ct` | R-15 `a\b` 字面断言 |
| 3 | `README.md` | 「## 能力对照表」 |
| 4 | `test/fsguard/r18_known_bypass.ct` | FSR-02 软链替换、FSR-03 硬链接；断言绕过成立 |
| 5 | `docs/acceptance/fsguard-manual-checks.md` | FSR-04 Darwin 弱变体与 Linux `mount --bind` / userns 步骤 |
| 6 | `tools/check.sh` | `g3-ph04`（r03/r15/r18/all）+ `g4-static` 的文档口径核对 |
| 7 | `test/fsguard/r03_coexist.ct`、`r03_qualified.ct`、`r03_ambiguous.ct`、`r03aux/` | R-03 判据 1/2/3 的共存、限定调用与歧义负例 |
| 8 | `ct.lock` | `dep = std@0.3.2` 的解析结果（D-014）；`vendor/` 不提交 |
| 9 | `docs/reviews/fsguard-b003-battle.md` | B-003 三问的 battle 与裁定 |
| 10 | `docs/phases/PH-04/card.md` | 本卡 |

## 任务清单

| 任务 | 内容 | 验证 | 规模 | 回滚 |
| --- | --- | --- | --- | --- |
| T-01 | 六处文档口径更正 | `bash tools/check.sh g4-static` | S | `git revert <T-01 提交>` |
| T-02 | R-15 `a\b` 字面断言 | `bash tools/check.sh g3-ph04 r15` | S | `git revert <T-02 提交>` |
| T-03 | R-16 README 能力对照表 + 门禁 grep | `bash tools/check.sh g3-ph04 all` | S | `git revert <T-03 提交>` |
| T-04 | FSR-02/03 `known_bypass` 负例 | `bash tools/check.sh g3-ph04 r18` | S | `git revert <T-04 提交>` |
| T-05 | FSR-04 手工清单 | `bash tools/check.sh g3-ph04 all` | S | `git revert <T-05 提交>` |
| T-06 | 卡面挂起项与门禁收口 | `bash tools/check.sh all` | S | `git revert <T-06 提交>` |
| T-07 | R-03 判据 1/2/3：`dep` + `ct.lock`、三个用例进 `g3-ph04 r03` | `bash tools/check.sh g3-ph04 r03` | M | `git revert <T-07 提交>`；`ct.lock` 可回退到无依赖状态 |

## 裁定记录

| 项 | 内容 |
| --- | --- |
| battle | `docs/reviews/fsguard-r01-r02-battle.md`（B-002，裁定 C） |
| 决策 | `docs/decisions/D-013.md`（签字：主控（用户授权 2026-11-16 battle）） |
| R-01 判据 2/3 去向 | 打包 1.1（`publisher`/`ns-root` 已提交）+ PH-05 首任务；验收必须实际 build + 运行，不得只看 `ct install` rc=0（PKG-6 open） |
| R-02 限定名去向 | PH-05；触发条件 `ct >= v0.59.0`（LANG-15 / PH-57）后复跑限定名用例，未触发前不实施 |
| battle（R-03/D-011） | `docs/reviews/fsguard-b003-battle.md`（B-003，三问裁定）；决策 `D-014`（依赖口径）、`D-015`（`ct install` `.m.ct`）、`D-016`（包根陈旧条目） |
| R-03 去向 | **本相落地**：`dep = std@0.3.2` + `ct.lock`；用例 `r03_coexist` / `r03_qualified` / `r03_ambiguous`；`ct install` 的 `.m.ct` 缺陷登记 `issues/FSG-02.md`，验收走 `ct build` + 运行 |
| D-011 状态 | `superseded`（依赖部分由 D-014 取代）；「不拆包、单命名空间」继续有效 |
| 不变 | 判据原文、验收命令与需求条目不动；R-17 仍挂起，PH-04 仍不得收口 |

## 退出判据

| # | 判据 | 验证 | 期望 |
| --- | --- | --- | --- |
| E-1 | 六处文档口径逐项命中：status 标题 `D-001…D-012`、无 `0.44.1`、roadmap `15 条可验收、2 条部分可验收`、三卡 `status: closed`、FSR-05/06 `已收口`、overlap 无 `S-6` 表格行 | `bash tools/check.sh g4-static` | rc=0 |
| E-2 | R-15：`a\b` 原样保留、`.` 不在反斜杠段折叠、`\` 不作段边界、驱动器形式不解析；`src` 无 Win32 分支 | `bash tools/check.sh g3-ph04 r15` | rc=0，7 checks |
| E-3 | R-16：README「能力对照表」覆盖本包符号与 std 四原语；trait 恰为四名；不暴露 `exists`/`readFile`/`writeFile`/`list` | `bash tools/check.sh g3-ph04 all` | rc=0 |
| E-4 | FSR-02/03：`check` 通过后换软链，读到根外哨兵；硬链接读根外 inode；失败提示要求重开 D-012 | `bash tools/check.sh g3-ph04 r18` | rc=0；不支持硬链接时 rc=3 + `skip:`，不算通过 |
| E-5 | FSR-04 手工清单含 `hdiutil`、`mount --bind`、`weaker variant`、`userns` | `bash tools/check.sh g3-ph04 all` | rc=0 |
| E-6 | 前半全绿 | `bash tools/check.sh all` | rc=0（`g7-leak` 在 Darwin SKIP；`g7-lsan-record` 单独跑，仍红） |
| E-7 | R-03 三条判据已落地（共存 / 限定调用 / 歧义负例）；R-17 仍挂起；R-01 判据 2/3 与 R-02 已按 D-013 移出 | `bash tools/check.sh g3-ph04 r03` | rc=0；卡内含 `R-03`、`R-17`、`D-013`、`D-014` |
| E-8 | **前半全绿 + R-03 落地 + R-17 未完成时 PH-04 不得收口**（R-17 是唯一剩余阻塞项） | 人工核对 | 卡状态保持 `in-progress`，不得改 `closed`；R-17 完成后自动满足 |
| E-9 | 任务清单每项可独立验收（6.6 T-6） | 人工核对 | 是 |

## 依赖

- D-011（不拆 path 包、单命名空间；依赖部分已由 D-014 取代）、D-012（词法策略层，非安全边界）、D-014（std 依赖口径）、D-015（`ct install` `.m.ct` 处置）、D-016（包根陈旧条目）。
- `docs/reviews/fsguard-fsr-battle.md`（B-001）、`fsguard-r01-r02-battle.md`（B-002）、`fsguard-b003-battle.md`（B-003）与各自落地记录。
- `docs/reviews/fsguard-std-overlap.md` §3（符号级对照）作为 README 能力对照表的事实来源。
- 后半四项的外部依赖见「范围」表的挂起条件。

## 已知风险

- `known_bypass` 固化的是「已知绕过」，不是功能承诺；用例名、注释与 D-012 三处同时否定，失败即提示行为变化需重开 D-012。
- 硬链接在不支持的文件系统上 SKIP，SKIP 不算通过；CI 需用 ext4/tmpfs/APFS。
- FSR-04 平台差异大（macOS 无 nullfs、Linux 需 root/userns），只写手工清单，不进 CI。
- R-16 判据 1（std 仓 diff 为空）本仓无法自证，只能核对「零引用」；std 侧以只读 `git status` 为准。
- 后半四项没有实现，因此本卡即使前半全绿也不能收口；`g7-lsan-record` 的红色是挂起信号，不是回归。
