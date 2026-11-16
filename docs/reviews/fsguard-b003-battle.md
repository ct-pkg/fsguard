# PH-04 三件待决事项 battle（B-003）

> battle_id: B-003
> scope: ① D-011（禁止 `ct.pkg` 新增 std 依赖）是否由新决策取代、门禁口径怎么定；② `ct install` 不识别 `.m.ct` 的上游缺陷怎么处置；③ 包根 `ct/std/0.3.1` 摘要不符条目怎么处理
> date: 2026-11-16
> host: Darwin 27.2.0 arm64；`ct v0.62.0`（`~/.local/bin/ct`）
> discipline: 大决定先核需求与 roadmap 方向，方向不符即停手；battle 只在小事上自决；不删已推 tag、不 force push、不改写历史

## 0 结论摘要

| # | 事项 | 性质 | 裁定 | 落地 |
| --- | --- | --- | --- | --- |
| 1 | D-011 去留与门禁口径 | **大决定**（改已定决策）→ 先核方向 | **方向内核过**：R-03 判据 1/2 要求与其他包同文件并存运行；没有需求条文要求「零依赖」。D-011 由 **D-014 取代**；门禁取 **B：声明了就必须可解析并记入 lock**（不要求「必须有」） | `D-014.md`；`ct.pkg` 保留 `dep = std@0.3.2`；提交 `ct.lock`；g0 改反向守卫 + g6 负例 |
| 2 | `ct install` 不识别 `.m.ct` | 小事（门禁实现方式） | **B：门禁用 `ct build` 验证，install 红单独登记**，不等上游、不改 ct-lang | `issues/FSG-02.md`（附原文与上游锚点）；`g3-ph04 r03` 走 build+run |
| 3 | `~/.ct/pkg/ct/std/0.3.1` 摘要不符 | 小事（缓存怎么挪） | **B：整体挪到可回退位置并留记录**，不删除 | 已挪到 `~/.ct/pkg-backup/20261116/ct/std/0.3.1`；记录见 `fsguard-pkg-store-migration.md` 与备份目录 `MIGRATION.md` |

一句话：**D-011 的两条立论前提都已不成立，且 R-03 的验收本来就要求 std 可用；把「不依赖」改成「依赖必须真实可解析」，是把守卫从政策改成一致性，不是放宽。**

## 1 事实底座（立论前先核）

### 1.1 方向核对（大决定必须先过这一关）

| 核对项 | 原文位置 | 内容 | 与「fsguard 依赖 std」的关系 |
| --- | --- | --- | --- |
| R-03 判据 1 | `docs/requirements.md:60` | 同文件 import `std::fs::Fs` + 本包，对同一 `char *` 调 `exists()` 与 `read_chunk(...)` 并各自 assert（运行） | **要求 std 在构建里可用**；不引进依赖就只能靠环境里散落的 `-I` |
| R-03 判据 2 | `docs/requirements.md:61` | 同文件 import `std::str::String` + 本包，调 `len()` 与 `read_chunk(...)` 并 assert（运行） | 同上 |
| R-16 判据 1/2 | `docs/requirements.md:239-241` | std 仓零改动；不在 `char *` 上暴露 `exists`/`readFile`/`writeFile`/`list` | 约束的是**不改 std**、不重名，不是「不依赖 std」 |
| roadmap PH-04 | `docs/planning/fsguard-roadmap.md:60-66` | 覆盖 R-03；「四个方法名与 22 个 std 名字无交集」 | 把 std 共存列为 PH-04 的退出内容 |
| D-011 的「零依赖」 | `docs/decisions/D-011.md:36` | 「fsguard 不新增 `dep = std`，`ct.pkg` 保持零依赖」 | **这是决策结论，不是需求条文**；需求与 roadmap 里没有对应约束 |

结论：**「依赖 std」与需求大方向不冲突，反而是 R-03 验收的前提。** D-011 可以被取代；但取代的理由必须是对其前提的证伪，不是「为了让门禁变绿」。

### 1.2 D-011 的两条前提均过期

| 前提 | D-011 原文 | 现在的事实 | 证据 |
| --- | --- | --- | --- |
| 许可 | std 是 `GPL-3.0-or-later WITH GCC-exception-3.1`，硬依赖会把许可义务带进 MIT 包 | std 0.3.2 为 **MIT** | `~/.ct/pkg/std/std/0.3.2/ct.pkg`：`publisher = std`、`licence = MIT`；本地 std 仓 `64d51c1` 起 LICENSE 为 MIT |
| 构建自足 | 硬依赖要求每个消费者与门禁持有 `vendor/std`，而 `vendor` 不进版本库 | v0.62.0 的 `ct get` 落共享包根（`~/.ct/pkg/std/std/0.3.2`），`ct build` 读 `ct.lock` 自动补 `-I`，**不需要 vendor** | 见 1.3 实测 |

### 1.3 依赖声明 + lock 的实测（ct v0.62.0）

```console
$ cd /Users/samxx/trae-ws/ct-fsguard
$ ct get std@0.3.2
installed 1 package(s)
$ cat ct.lock
# ct-lock 2
std/std 0.3.2 git https://github.com/ct-pkg/std a3f12172e03a9247ef47dec1dca66309d3111ac2 . sha256:95fc010f704d67e8718574d2419fab48063029c0f9e6cd18961f4e423088ce6d
$ ct install
ct build --ldflags '-lm' <unit>.ct -o build
# lock-format: v2
$ ct verify
verified 1 package(s)
```

`ct build` 的实际 cc 行（无 `vendor/`，包含根来自包根）：

```console
$ ct build test/fsguard/r03_coexist.ct -I src --cflags "-Isrc" -o /tmp/r03_coexist
'cc' -std=c99 -Isrc -I 'src/fsguard' \
     -I '/Users/samxx/.ct/pkg/std/std/0.3.2/std/fs' \
     -I '/Users/samxx/.ct/pkg/std/std/0.3.2/std/str' \
     -I '.ctbuild' '.ctbuild/r03_coexist.c' '.ctbuild/FsGuard.c' '-o' '/tmp/r03_coexist'
$ /tmp/r03_coexist; echo $?
0
```

## 2 事项一：D-011 的去留与门禁口径

### 2.1 三席

| 席 | 主张 | 依据 |
| --- | --- | --- |
| A（维持 D-011） | 继续禁止 `dep = std`；R-03 判据 1/2 用测试时的临时 `-I` 满足 | 「零依赖」曾写进决策；依赖会把 fsguard 与 std 的版本节奏绑在一起 |
| B（取代 D-011，门禁 = 声明即须可解析并记入 lock） | 允许 `dep`；门禁只验证「声明了就必须真能解析、且 lock 有对应条目」 | 许可与自足两条前提均已证伪；R-03 验收本来就要求 std 可用；版本绑定由 `dep = std@0.3.2` 的显式版本 + lock 摘要控制 |
| C（取代 D-011，门禁 = 必须有 std 依赖） | 反过来强制 `dep = std` 必须在 | 与 A 对称，能把「声明被误删」也挡住 |

### 2.2 相互反驳

- **A 反 B**：依赖会让消费者多一个包根，未来 std 破坏性升级会传导。
  **B 答**：`dep = std@0.3.2` 钉版本、`ct.lock` 钉摘要，升级是一次显式提交；且 R-03 要求两个包在同一构建单元并存，测试环境必须与消费者一致，临时 `-I` 反而掩盖真实消费路径（`fsguard-std-overlap.md §7` 已经吃过一次这个亏）。
- **A 反 B**：D-011 明写「零依赖同时是工程约束」。
  **B 答**：该约束的理由是「`vendor` 不进版本库 → 非自足」；v0.62.0 已改成共享包根 + lock，理由消失。约束随理由一起失效，不能只留结论。
- **C 反 B**：不强制「必须有」，就允许有人悄悄删掉 `dep` 而门禁不响。
  **B 答**：删掉 `dep` 会让 R-03 用例直接构建失败（`cannot resolve import std/fs/Fs`），且 `g3-ph04 r03` 是普通门禁的一部分——用例本身就是守卫。强制「必须有」则把实现细节写成政策：若将来 R-03 用例迁到独立消费者工程，本包 `ct.pkg` 并不需要这条强制。
- **C 反 B（第二击）**：那 `dep` 写了但没人用、或写了但解析不到不同样是缺陷？
  **B 答**：这正是 B 的口径要挡的两种病：「写了但解析不到 / 没进 lock」（死声明）与「实际 import 却没声明」（隐式依赖，靠环境 `-I` 蒙混）。B 对前者直接判红，对后者由 `ct verify` + 用例构建兜住。

### 2.3 裁定

**取代 D-011（D-014），门禁取 B。**

- `ct.pkg` 的 `dep = std@0.3.2` 保留；提交 `ct.lock`；`vendor/` 不进版本库。
- g0 的守卫从「禁止 `^dep = std`」改为：
  1. `ct.pkg` 若出现 `dep = std@<ver>`，`ct.lock` 必须含 `std/std <ver>` 行；
  2. lock 行的版本必须与 `ct.pkg` 的版本一致；
  3. `ct verify` rc=0（在 `g3-ph04 r03` 或专用门禁里实测，不只看 grep）。
- 保留 D-011 的另一半：**不拆包、单命名空间**（`src` 下仍只有 `fsguard` 一个目录）。拆包问题按 D-011 原失效条件继续观察。
- 按 G8/T-7 加负例：删掉 `dep` → g0 不因「缺依赖」报错但 R-03 用例构建失败；删掉 lock 行或改错版本 → g0 报错。

### 2.4 代价与残留风险

- 消费者多一个包根（`-I` 由 lock 自动补，手工命令不受影响）。
- std 若发布 0.4.x 破坏性变更，升级是一次显式提交（`dep` + `ct.lock` 同步），不会静默跟随。
- 门禁不再检查「是否依赖」，只看「依赖是否真实」；若未来要恢复「零依赖」政策，需再出一条决策，不能在门禁里暗改。

## 3 事项二：`ct install` 不识别 `.m.ct`

### 3.1 事实

消费者 `/tmp/fsg-install-probe`（`ct.pkg` 声明 `dep = std@0.3.2`，`main.ct` 只有 `import std::fs::Fs;`）：

```console
$ ct get std@0.3.2
installed 1 package(s)
$ ct install
ctc: 'main.ct' cannot resolve import 'std/fs/Fs'
INSTALL_RC=1
$ ct build main.ct -o probe
'cc' -std=c99 -I '/Users/samxx/.ct/pkg/std/std/0.3.2/std/fs' -I '.ctbuild' '.ctbuild/main.c' '-o' 'probe'
BUILD_RC=0
$ ./probe; echo $?
0
```

同一消费者把 import 换成 `.h.ct` 形态（`std::io::Io`）时 `ct install` rc=0。根因在安装器的 import 校验只 stat 两种文件名：

- `ct-lang/selfhost/ct-ast/tool/pkg/Pkg.h.ct:1609-1618`：`snprintf(cand, "%s.h.ct", rel)`、`snprintf(cand, "%s.ct", rel)`，**漏掉 `%s.m.ct`**。
- 上游议题 `PKG-6`（`ct install` 不校验 import）仍 open；本条是它之外更具体的一处：校验存在，但漏了 `.m.ct` 这一种单元。

### 3.2 三席

| 席 | 主张 | 依据 |
| --- | --- | --- |
| A（等上游修） | `ct install` 红了就等 ct-lang 修好再验收 | 不在本仓改 ct-lang；修好后 install 自然绿 |
| B（门禁用 `ct build`，install 红登记） | 验收信号改成 `ct build` + 运行；install 的缺陷单独立案，不阻塞 R-03 | `.m.ct` 是 std::fs / std::str 的唯一单元形态，等上游等于把 R-03 无限期挂起 |
| C（在门禁里绕开 install，例如自己生成 `-I`） | 门禁自己算包含根，不依赖 install | 能让门禁绿，但把「消费者只靠包管理器」这个主张偷偷换掉 |

### 3.3 相互反驳

- **A 反 B**：验收命令里写着 `ct install`，跳过它等于降标准。
  **B 答**：`ct install` 的职责是「按 lock 校验 store 并打印建议命令」，不是「证明 import 可解析」——它 rc=0 也不等于可解析（PKG-6）。真正的主张是「消费者装上就能 build 并运行」，用 `ct build` + 运行来证明比用 install 的 rc 更接近主张。
- **B 反 C**：C 会让门禁自己推包含根，掩盖安装根是否真的对。
  **C 答**：v0.62.0 的 `ct build` 已经按 lock 自动补 `-I`，C 的「自己算」没有必要，也会让测试环境偏离消费者。
- **A 反 B（第二击）**：登记了但没人修，红色会不会被遗忘？
  **B 答**：issue 带原文、上游锚点与「何时可撤」的触发条件，并由 `g3-ph04 r03` 的绿色证明真正的验收路径可用；install 缺陷在 FSG-02 里随上游修复关闭。

### 3.4 裁定

**取 B。** 门禁的 R-03 验收 = `ct build` + 运行断言；`ct install` 的 `.m.ct` 缺陷登记为 `FSG-02`（附原文与 `Pkg.h.ct:1609-1618` 锚点），不修改 ct-lang、不 vendor、不在门禁里自算包含根。

残留风险：`ct install` 在 `.m.ct` 消费者上仍会红；任何「只跑 install 就宣布可用」的验收都是假绿。已在 FSG-02 写明。

## 4 事项三：`~/.ct/pkg/ct/std/0.3.1` 摘要不符条目

### 4.1 事实

- 该目录的 `ct.pkg`：`name = std`、`publisher = ct`、`version = 0.3.1`、`licence = GPL-3.0-or-later WITH GCC-exception-3.1`。
- 现行可消费的是 `~/.ct/pkg/std/std/0.3.2`（`publisher = std`、MIT）。
- 任何按 `std@0.3.1` 的解析都会被挡住：

```console
$ ct get std@0.3.1
ctc: store '/Users/samxx/.ct/pkg/ct/std/0.3.1' already exists with a different digest
```

- 没有已安装包声明对 `ct/std/0.3.1` 的依赖（`grep '^dep' ~/.ct/pkg/*/*/*/ct.pkg` 无命中），挪走不破坏任何消费者。

### 4.2 三席

| 席 | 主张 | 代价 |
| --- | --- | --- |
| A（删除） | 陈旧且摘要不符，删掉最干净 | 不可回退；违反本轮「不要直接删」的约束 |
| B（整体挪到备份位置 + 记录） | 保留内容与回退路径，包根不再被它挡 | 需要维护一条迁移记录 |
| C（原地保留） | 不动最省事 | `std@0.3.1` 永远解析失败；后续排障会重复踩 |

### 4.3 裁定

**取 B，已执行。**

- 原路径 → `/Users/samxx/.ct/pkg-backup/20261116/ct/std/0.3.1`（71 个文件；内容摘要 `aae37735…`；归档摘要 `531eacb8…`）。
- 记录两处：备份目录 `MIGRATION.md`（含回退命令）与本仓 `docs/reviews/fsguard-pkg-store-migration.md`。
- 迁移后 `ct install` rc=0、`ct verify` 通过、`g3-ph04 r03` 全绿，证明包根解析走 `std/std/0.3.2`，与旧条目无关。

## 5 对 E-7 / E-8 一类判据的连带影响

- **E-7 不再把 R-03 列为挂起项**：R-03 三条判据全部落地；E-7 只保留 R-17（若 Linux 记录未回填）与已按 D-013 移出的 R-01 2/3、R-02 的去向说明。
- **E-8 的「不得收口」约束只由 R-17 决定**：R-03 不再是阻塞项；R-17 若完成则 E-8 自动满足，若 Podman 跑不起来则登记环境缺口并保持 `in-progress`，不伪造 Linux 记录。
- **教训固化**：判据里出现「依赖某个机制落地」这种话时，必须同时写「怎么验证该机制已落地」；否则判据会从「等上游」滑成「永远不验」。R-03 之前把「共享库机制」当成挂起理由，实际 v0.62.0 早已支持同名歧义与限定调用——本次以可执行的三个用例把这条判据补实。
