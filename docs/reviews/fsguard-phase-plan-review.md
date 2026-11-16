# fsguard phase 规划复核（2026-11-17）

> 目的：回答「phase 规划是否混乱」，为 PH-05 立项与后续收口提供依据。
> 口径：只看仓库内文档与门禁；不把会话结论当事实。
> 结论：**主链有序，尾部断尾**。PH-01→PH-04 的依赖顺序与覆盖没有冲突；问题集中在 PH-04 收口后留下的三条移出项没有 phase 承接，以及若干状态口径停在 PH-04 之前。

## 1 复核方法

1. 逐张读 `docs/phases/PH-0*/card.md`，核对目标、范围、任务、退出判据与 `version-minor`。
2. 用 `docs/planning/fsguard-roadmap.md` §1 的覆盖表对 R-01…R-17 做覆盖核对。
3. 用 `docs/acceptance/fsguard-status.md` 的 R 状态表与各卡收口记录交叉核对。
4. 跑 `bash tools/check.sh all`，确认 12 个门禁当前为绿，排除「文档说绿、实际红」。
5. 读 `AGENTS.md` 0.1/0.3、`docs/session-map.md`、`docs/planning/fsguard-packaging.md`，核对实例化与派发信息是否跟得上。

## 2 没问题的部分

| 项 | 判断 | 依据 |
| --- | --- | --- |
| phase 顺序 | 有序：PH-01 词法 → PH-02 读写 → PH-03 遍历 → PH-04 包形态，前置关系与依赖一致 | 四张卡的「依赖」节与 roadmap §1 |
| phase 粒度 | 每相有独立目标、交付物、退出判据；任务按 6.6 切成 S/M，未出现「一个任务交整相」 | 四张卡任务表；`g1-phase-card` 通过 |
| 退出判据 | 每条都有命令或可核对锚点；没有 TBD | 四张卡退出判据表；`g1-command` 通过 |
| 门禁现状 | 12 个门禁实际执行，`all` rc=0（Darwin 的 `g7-leak` 为 SKIP，不是泄漏结论） | 2026-11-17 实跑输出 |
| 版本主链 | `ct.pkg#version = 0.4.0`，`v0.4.0` tag 指向 PH-04 收口提交，CHANGELOG 有 0.1.0～0.4.0 | `git tag -n`、`CHANGELOG.md` |

## 3 断尾与不一致（按严重度）

| # | 问题 | 证据 | 影响 | 处置 |
| --- | --- | --- | --- | --- |
| P-1 | **PH-05 被点名但没有卡**：D-013、PH-04 卡、roadmap §3 都把 R-01 判据 2/3 与 R-02 判据 2 指向 PH-05，但 `docs/phases/` 只有 PH-01…PH-04 | `grep -rn 'PH-05' docs` 命中多处；`ls docs/phases` 无 PH-05 | 三条移出项没有范围、任务与退出判据，无法开工，也无法收口 | 新建 `docs/phases/PH-05/card.md` |
| P-2 | **覆盖统计与 R-01 状态矛盾**：状态表写「15 条可验收、2 条部分（R-02/R-17）」，但同表 R-01 行写「判据 1/4 已实施；判据 2/3 移出」，R-01 实际也是部分 | `docs/acceptance/fsguard-status.md:8` 与 §4 R-01 行；roadmap §0 同口径 | 读者会以为只剩 2 条部分，漏掉 R-01 的消费者夹具 | 状态表改 14/3；PH-05 收口后改 17/0 |
| P-3 | **AGENTS 实例化停在 PH-04 之前**：`版本落点` 写「当前 0.1.0；PH-01 的 version-minor 为 1」，`Issue 台账` 写 FSG-01 为 open，`决策记录` 只到 D-013 | `AGENTS.md:266-271` | 每轮加载的实参失真，后续会话会按旧版本/旧台账行动 | 更新为 0.4.0 / PH-05 / D-016 / FSG-01 fixed、FSG-02/03 open |
| P-4 | **验收命令块停在实现前**：R-07/R-10/R-13 仍写不存在的 `ct run`；R-01 写「待建夹具」；R-02 写「挂起」；R-03 写「判据 1/2/3 挂起」 | `docs/acceptance/fsguard-commands.md` 对应节 | 判据命令不可执行，违反「门禁能真跑」 | 改为现行 `bash tools/check.sh g3-*` |
| P-5 | **打包计划的阶段判断过期**：1.3 还写「打 v0.1.0」，§4.3 写「前三步完成后 PH-04 才具备收口条件；此前保持 in-progress」，而 PH-04 已收口且 v0.4.0 已打 | `docs/planning/fsguard-packaging.md` 1.3、§4.3/§4.4 | 与 phase 状态、tag 现状冲突 | 标注 1.3 已由 PH-04 收口覆盖；1.2 保持「等 C 头包含根」；§4 更新到 PH-05 |
| P-6 | **门禁不认识 PH-05**：`g1-phase-card` 的 `all` 与 `case` 只列 PH-01…PH-04 | `tools/check.sh` `g1_phase_card` | 新卡建了也不会被校验，等于没有门禁 | 增加 PH-05，并补一个负例 |
| P-7 | **规范 pin 落后（范围外）**：`AGENTS.md` pin 1.10.0，主规范已是 1.15.0；`sync-agents.sh --check` 失败 | 2026-11-17 实跑 | 规范锚定 G9 不过；但属独立治理项，不应夹进 PH-05 实施 | 不在本 phase 改；登记为后续独立事项，PH-05 只按项目 pin 的 1.10.0 执行 |

## 4 判断

- **不是全盘混乱**：四相的目标、覆盖、依赖与门禁没有互相打架，也没有需要重排的 phase。
- **是尾部断尾**：PH-04 把三条判据移出后，只写了「去向 PH-05」，没有把 PH-05 作为 phase 建出来；同时状态统计、AGENTS 实参、验收命令、打包计划都停在移出前。读者会同时看到「PH-04 已收口」「R-01 判据 2/3 待做」「没有 PH-05 卡」三个互相矛盾的事实。
- **处置顺序**：先补 PH-05 卡与实参（不写实现），再按 6.6 切三个任务并逐个收口；PH-05 收口后，roadmap 的「17 条全部可验收」才有依据。

## 5 PH-05 的范围边界

PH-05 只做三件已有去向的事，不新增功能：

1. R-01 判据 2/3：消费者只 import 本包单元，对 `char *` 调四个方法并断言返回值，`FsWalkCb` 可见且实际被调用。
2. R-02 判据 2：裸名与限定名分别取值并断言（本机 `ct v0.62.0` 已支持 `FsErrCode::FS_ERR_*`）。
3. R-17 判据 5：Linux 上 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` 的实测记录。

不做：不改需求正文、不改判据原文、不新增 API、不处理 FSG-02 上游缺陷、不动 G9 的规范 pin。

## 6 复核后的动作

| 动作 | 产物 |
| --- | --- |
| 建 PH-05 卡（本文件同轮） | `docs/phases/PH-05/card.md` |
| 修正状态统计与去向 | `docs/acceptance/fsguard-status.md`、`docs/planning/fsguard-roadmap.md` |
| 修正实例化 | `AGENTS.md` 0.1 |
| 修正验收命令 | `docs/acceptance/fsguard-commands.md` |
| 修正打包计划陈判处 | `docs/planning/fsguard-packaging.md` |
| 门禁支持 PH-05 | `tools/check.sh`（`g1-phase-card`、`g3-ph05`、`g4-static`、`all`） |
