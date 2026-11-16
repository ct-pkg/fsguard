# PH-05 收口回顾（2026-11-17）

> phase: PH-05「收口三项挂起验收」
> 收口提交：`faada49`；tag：`v0.5.0`
> 口径：每条教训必须落到门禁、规范或明确不采纳；写成感想的回顾不算完成。

## 1 交付

| 项 | 结果 |
| --- | --- |
| R-01 判据 2/3 | `test/consumer/consumer.ct`，`g3-ph05 consumer` 16 checks |
| R-02 判据 2 | `r02_errors.ct` 补 11 条限定名断言，`g3-ph01 r02` 22 checks |
| R-17 判据 5 | Linux（Debian 12 / aarch64 / gcc 12.2.0）`g7-leak` PASS，`g7-lsan-record` rc=0 |
| 规划断尾 | `docs/phases/PH-05/card.md`、roadmap、AGENTS 0.1、验收命令、打包计划同步 |
| 版本 | `0.5.0`；annotated tag `v0.5.0`（`1457c86`）指向 `faada49`；`main` 与 tag 已推送 |

## 2 教训与落点

| # | 教训 | landing |
| --- | --- | --- |
| L-1 | 把判据移出 phase 时必须同时建承接卡；只写“去向 PH-05”会留下没有范围、任务、退出判据的空档 | `gate:g1-phase-card`（PH-05 纳入 `all`；`g6-contract` 增加缺 `version-minor` 必红负例） |
| L-2 | 状态表的“N 条可验收”必须与每条 R 自己的状态交叉核对；R-01 当时也是部分，15/2 算错 | `gate:g4-static`（roadmap 改 17/0；状态表逐条对齐） |
| L-3 | 验收命令不能停在目标态写法；`ct run` 不存在会让读者照做失败 | `gate:g1-command` + `docs/acceptance/fsguard-commands.md` 改为现行 `g3-*` |
| L-4 | 环境缺口不能用 Darwin 的 SKIP 顶替；必须拿真实 Linux 主机跑同一条门禁并回填原始输出 | `gate:g7-lsan-record`（记录缺 host/命令/PASS 任一即红） |
| L-5 | 规范 pin 落后是跨切面治理项，不能夹进 phase 的实施提交；应单独登记、单独提交 | `rejected:夹进 PH-05`（登记 FSG-04；按 11.5 L-4 用两文件提交刷新） |
| L-6 | 单会话闭环下，`session-map.md` 的四列只能是计划路由，不能伪装成独立 UI 会话 | `spec:9.5`（表内写明“单会话执行，不声称独立会话”） |

## 3 Issues 去向

| Issue | 去向 | 说明 |
| --- | --- | --- |
| FSG-01 | 已 `fixed`（PH-04） | 版本链断裂由 DEV-001 一次性补号收敛 |
| FSG-02 | 保持 `open`（上游） | `ct v0.62.0` 仍不能 `ct install` 只 import `.m.ct` 的消费者；本仓按 D-015 走 `ct build` + 运行 |
| FSG-03 | `fixed`（PH-05 T-03） | Linux LSan 记录回填，`g7-lsan-record` rc=0 |
| FSG-04 | `fixed`（2026-11-17） | 生成块与全文副本刷新到 1.15.0，`sync-agents.sh --check` rc=0 |

## 4 未消解清单

按 6.7 清点：**1 条**（C-6，`deviation:` 的收敛方式与 V-1「不许多跳」）。本相未新增偏离；DEV-001 已收敛为偏移 0。

## 5 残留风险

- 已按用户 2026-11-17 的「继续推进直到全部完成扫尾」指令推送：`main` → `212318e`，`v0.5.0` annotated tag `1457c86` → `faada49`；V-7 四项校验（tag 名、annotated、指向收口提交、远端可追溯）全过。
- 项目按 1.15.0 的 §9.8 目录边界执行；本次取证使用 `/tmp` 与规范来源只读项，未写其他项目工作树。
- `docs/session-map.md` 的四列是计划路由，实际执行在 lead 单会话内完成；若后续拆出独立 phase 对话，按 9.3 改名并补 `reason` 列。
