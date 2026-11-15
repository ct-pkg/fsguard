# R-01 判据 2/3 与 R-02 限定名处置 battle（B-002）

> battle_id: B-002
> scope: R-01 判据 2/3（消费者只 import 本包 `.m.ct`）、R-02 判据 2（`FsErrCode::FS_ERR_*` 限定名）
> source: `docs/phases/PH-04/card.md`、`docs/requirements.md:29-53`、ct-lang 仓库 `issues/` 与 `docs/planning/`
> date: 2026-11-16
> host: Darwin 27.2.0 arm64；`ct v0.58.0`（`~/.local/bin/ct`）
> discipline: 只出结论与实测；本轮不改判据原文、不改 golden；落地只动归属与卡面

## 0 结论摘要

| 项 | 上游状态 | 本机实测 | 裁定 |
| --- | --- | --- | --- |
| R-01 判据 2/3 | **已交付**：PKG-2 已解决（v0.55.0 `ns-root`、v0.58.0 `ct build` 读 lock） | `ct install` 打印 `-I …/src`；`ct build` 不再报 `cannot resolve import`；C 头包含根需 `--cflags` | **移出 PH-04**（C 的变体）：转打包 1.1 + PH-05 首任务；判据原文不动 |
| R-02 判据 2 | **未交付**：LANG-15 open，排 PH-57 / v0.59.0 | 仍报 `qualified type names are not supported` | **移出 PH-04**（C）：转 PH-05，触发 `ct >= v0.59.0` |

一句话：**R-01 的上游阻塞已经消失，剩下的全是本仓自己的活；R-02 确实是上游缺口，但它不该继续卡住 PH-04。**

## 1 先核事实（立论之前）

### 1.1 上游仓库证据

`/Users/samxx/trae-ws/ct-lang` HEAD `d22f0727`（v0.58.1 已交付后）：

| 证据 | 位置 | 内容 |
| --- | --- | --- |
| PKG-2 包根 import | `issues/packages/pkg-2-ct-install-package-root-import.md:9` | 状态 **已解决**：v0.55.0 起 `ns-root` 决定 `-I`；v0.58.0 起 `ct build` 默认读 lock 自动补 `-I` |
| PKG-6 install 校验 | `issues/packages/pkg-6-install-does-not-validate-imports.md:10` | 仍 open；`ct install` 的 rc=0 **不等于** import 可解析 |
| LANG-15 限定名 | `issues/lang/lang-15-qualified-enum-member-value.md:9`、`:57` | open；新特性，落点 PH-57「限定名与 namespace 常量」 |
| PH-57 版本 | `docs/planning/post-58-phase-sequence.md:57` | PH-57 → **v0.59.0**；判据含 `FsErrCode::FS_ERR_NOT_FOUND` 可用 |
| 排期 | `docs/planning/post-58-plan.md:70` | 「需要，并入 PH-57；PH-57 开卡」 |

### 1.2 本机实测（ct v0.58.0）

消费者工程 `/tmp/fsg-consumer`，`main.ct` 只写 `import fsguard::FsGuard;`：

```console
$ ct --version
ct v0.58.0
$ ct get /Users/samxx/trae-ws/ct-fsguard && ct install
vendored 1 package(s)
ct build -I <CT_HOME>/pkg/ct/fsguard/0.1.0/src main.ct -o build
INSTALL_RC=0
$ cat ct.lock
# ct-lock 2
ct/fsguard 0.1.0 dir /Users/samxx/trae-ws/ct-fsguard - src sha256:4c9a004654e364dc3249072a7637cfc9a06f366b2a0fd42b0a92e988b39c7646
```

`ct build main.ct -o build`（不传任何 `-I`）：

```console
ctc: note: 'ct/fsguard' resolves to the local directory (dev override): /Users/samxx/trae-ws/ct-fsguard
'cc' -std=c99 -I '.ctbuild' '.ctbuild/main.c' '.ctbuild/FsGuard.c' '-o' 'build'
.ctbuild/FsGuard.h:14:10: fatal error: 'fsguard/FsGuardOps.shim.h' file not found
BUILD_RC=1
```

**import 已解析**（没有 `cannot resolve import`），失败点是 C 编译阶段的头包含根。补一个显式 cflags 即可跑通：

```console
$ ct build main.ct --cflags "-I<仓库根>/src" -o build
'cc' -std=c99 -I<仓库根>/src -I '.ctbuild' '.ctbuild/main.c' '.ctbuild/FsGuard.c' '-o' 'build'
BUILD_RC=0
$ ./build; echo RUN_RC=$?
RUN_RC=0
```

（上面把绝对路径写成 `<CT_HOME>` / `<仓库根>`：`ct pkg check` 禁止文档出现绝对 `-I`，其余字符逐字保留。）

R-02 探针（ct v0.58.0）：

```console
$ ct build /tmp/r02probe/probe.ct -I src --cflags "-Isrc" -o /tmp/r02probe/probe
/tmp/r02probe/probe.ct:4:40: error: no variable of that name in that namespace (qualified type names are not supported; use the bare name or an alias import)
BUILD_RC=1
```

### 1.3 事实对三案的影响

- R-01：A 的前提（「等包机制能标准安装」）**已不成立**；B 想改的调用形式**本来就是可用的**；C 若要成立，理由只能是「归属与范围」，不能是「依赖上游」。
- R-02：A 成立但无日期；B 会改判据；C 成立且有明确版本触发条件。

## 2 三案立论

### A 等上游补齐能力，判据不动

- **主张席（REQ）**：两条都不改，等 ct 交付后复跑；判据最保守，零解释成本。
- **证据**：R-02 有 LANG-15 → PH-57 → v0.59.0 的明确排期（§1.1）；R-01 曾因 PKG-2 无法安装而红。
- **代价**：PH-04 的 E-8 把它与「前半全绿」绑死，等待期无上限；R-01 的上游阻塞其实已经解除，继续等是**空等**。

### B 改成当前版本认的调用形式

- **主张席（REQ）**：R-02 改为只用裸名 `FS_ERR_OUT_OF_BOUNDS`；R-01 改为只用源码根 `-I src` 的本地构建。
- **证据**：裸名与 `-I src` 在 v0.58.0 上均可运行（现有 `r02_errors` 11 checks、各相门禁均用该形式）。
- **代价**：**证据不再证明原主张**。R-02 判据 2 原文要求「裸名与限定名**分别**取值并 assert」——只留裸名，证明的是「常量可用」，不是「限定名可用」；R-01 判据 2/3 要的是「消费者只 import 本包」，退到源码根就绕开了包安装路径。故 B 只满足「门禁变绿」，不满足「主张成立」。

### C 把依赖上游能力的判据移出 PH-04 退出判据

- **主张席（REQ）**：PH-04 只对前半负责；上游依赖项写进需求池/下一 phase，判据原文保留。
- **证据**：PKG-6 open 说明安装器仍可能「假成功」；LANG-15 明确排到 v0.59.0 之后；PH-04 的 E-8 目前无法满足。
- **代价**：移出等于承认 PH-04 交付范围比 roadmap 原计划窄；必须写清去向、触发条件与验收命令，否则条目会「消失」。

## 3 相互反驳

| # | 反方 | 反驳 | 结论 |
| --- | --- | --- | --- |
| C-1 | A 对 R-01 | A 说「等包机制」，但 PKG-2 已解决、本机 v0.58.0 实测 import 已解析（§1.2） | A 对 R-01 **失效** |
| C-2 | A 对 R-02 | A 有排期但无日期；E-8 因此无限期挡住 PH-04 | A 对 R-02 **成立但不充分** |
| C-3 | B 对 R-02 | 裸名只证明常量可用；判据 2 要求两种写法并存 | B 对 R-02 **不成立**（削弱判据宽度） |
| C-4 | B 对 R-01 | 源码根构建绕开包安装路径，与判据 2「消费者只 import」不是同一主张 | B 对 R-01 **不成立** |
| C-5 | C 对 R-01 | C 原定义是「依赖上游能力」；R-01 已不依赖上游 | C 对 R-01 **需改理由**：按「归属（发布准备 1.1）」移出，不按「等上游」 |
| C-6 | C 对 R-02 | C 不删判据、只改归属，是否算放宽？ | **不算**：判据原文、验收命令、需求条目均不动；PH-05 承接并写死触发条件 |
| C-7 | 对 C 的整体 | 移出两条后 PH-04 是否就能收口？ | **不能**：R-03（等共享库）与 R-17（等 Linux）仍在，E-8 继续挡 |

## 4 裁定

1. **R-01 判据 2/3：移出 PH-04（C 的变体）**。判据原文不动；PH-04 保留判据 1/4。去向：打包 1.1（提交 `publisher`/`ns-root`）+ PH-05 首任务（消费者测试接入门禁）。消费者验收命令必须实际 `ct build` 并运行，不得只看 `ct install` 的 rc=0（PKG-6 open）。
2. **R-02 判据 2：移出 PH-04（C）**。去向：PH-05；触发条件写死为 `ct >= v0.59.0`（LANG-15 / PH-57 发布）后复跑限定名用例，未触发前不实施、不写跳过用例。
3. **不采纳 A（对 R-01 已失效、对 R-02 无期）与 B（不能证明原主张）**。
4. **E-7 / E-8 同步收紧为只列 R-03、R-17**；不得因两条移出而宣称 PH-04 可收口。

## 5 残留风险

| # | 风险 | 处置 |
| --- | --- | --- |
| K-1 | 上游 PH-57 无日期承诺，只有版本号 | 触发条件按 `ct >= v0.59.0` 写死；不按日历等 |
| K-2 | `ct install` 返回 0 不代表 import 可解析（PKG-6 open） | 消费者验收必须实际 build + 运行，禁止只看 install rc |
| K-3 | C 头包含根未由 lock 自动补，消费者仍需 `--cflags "-I<ns-root>"` | 写进打包 1.1 的验收命令；上游是否补 `cflags` 另记，不混入本条 |
| K-4 | 移出条目遗忘 | D-013 + roadmap §3 + PH-04 卡「裁定记录」三处同写去向与触发条件 |
| K-5 | 把「移出两条」误读为 PH-04 可收口 | E-8 明确仍受 R-03、R-17 约束 |

## 6 E-8 这类判据的连带影响

E-8 原文「前半全绿 + 后半仍挂起时 PH-04 不得收口」是**范围耦合**条款：它把「哪些项属于本 phase」与「能否收口」绑在一起。任何移出都必须同时改 E-7/E-8 的枚举，否则会出现「卡上说移出、判据仍要求挂起」的自相矛盾。本次处置守住两条边界：

- E-7/E-8 只改**枚举**（四项 → 两项），不改「前半全绿才可收口」的强度；
- 移出项的判据原文、验收命令与需求归属全部保留，并由 PH-05 承接，不出现「静默删除」。

## 7 签字

- 裁定：**C**（R-01 按归属移出、R-02 按上游依赖移出）
- 签字：主控（用户授权 2026-11-16 battle）
- 落地：`docs/decisions/D-013.md`；卡面与 roadmap 改动见该决策的 `affected`
