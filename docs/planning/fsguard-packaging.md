# fsguard 包安装与发布前置

本仓的单元在 `src/fsguard/`，包清单此前只写了 `name = fsguard`。消费者通过包管理器安装后，
安装器只按包名给出一个包含根，实际会报 `cannot resolve import 'fsguard/FsGuard'`。
下面四件事是把「装上就能 import」和「可发布」补齐。

**前提更正（2026-11-16 复核）**：安装器读取 `publisher`、编译器按 `ns-root` 补搜索根、
`ct build` 默认读 lock，三项在本机 `ct v0.58.0` 上均已实测体现（见 1.5），不再是挂起理由。
四项从「等能力出现」改判为「落地配置 + 提交包声明 + 建消费者夹具」，其中 1.1 现在就能做。

## 1 要做的四件事

### 1.1 包清单声明发布者与命名空间根

- **为什么**：消费者不应自己推算 `-I`；包清单需要说明「谁发布」以及「命名空间根在哪一层」。
  否则安装结果与源码布局对不上，消费者必失败。
- **要做什么**：`ct.pkg` 增加 `publisher = ct`、`ns-root = src`。两行已提交，`ct pkg check` 四条判据全过。
- **验收**：`grep -x 'publisher = ct' ct.pkg`、`grep -x 'ns-root = src' ct.pkg` 均命中；
  一个最小消费者只走包管理器安装、不手写任何 `-I`，能 import `fsguard::FsGuardOps`。
- **状态**：**已落地**（字段已提交，`ct pkg check` 四条判据全过）。2026-11-16 用 `ct v0.58.0` 实测：`ct install`
  已打印 `-I …/pkg/ct/fsguard/0.1.0/src` 的 build 命令，消费者 `import fsguard::FsGuard` 不再报
  `cannot resolve import`；但 C 头包含根仍需 `--cflags "-I<ns-root>"`，验收命令必须带它并实际运行。

### 1.2 构建命令不再手写包含根

- **为什么**：`ct.pkg` 没有 `cflags` 字段，`-Isrc` 实际上是写在构建命令里的：
  `tools/check.sh` 有 4 处 `ct build … -I src --cflags "-Isrc"`，文档示例也照抄了它。
  这些手写参数让测试用源码根、消费者用安装根，两条路径不一致，门禁会掩盖真实的安装问题。
- **要做什么**：删掉 `tools/check.sh` 四处的 `-I src` 与 `--cflags "-Isrc"`，
  并同步修正文档示例里的同样写法；`ct.pkg` 不新增 `cflags` 字段。
- **验收**：`grep -rn -- '-Isrc' tools/check.sh` 为 0 命中；`bash tools/check.sh all` 仍为 rc=0；
  消费者侧仍能只靠包管理器安装完成 import。
- **状态**：**仍不可开工**。`ct v0.62.0` 已认 `ns-root` 与 lock（import 侧可去掉 `-I src`），
  但 C 头包含根仍需 `--cflags "-Isrc"`；消费者夹具（PH-05 T-01）仍带该 cflags。
  在 `ct build` 把 `ns-root` 传给 C 编译器之前，不删门禁与消费者命令里的头包含根。

### 1.3 phase tag（原「打 `v0.1.0` tag」）

- **为什么**：发布点必须可核对；6.7 V-7 要求每个 phase 收口打 annotated tag。
- **现状**：`v0.1.0` 与 `v0.4.0` 均已存在；`v0.4.0` 指向 PH-04 收口提交 `120c236`，已推送到 origin。
  PH-05 收口时应打 `v0.5.0`，指向 PH-05 收口提交，message 含 `PH-05` 与收口提交 sha 前 7 位。
- **验收**：`git cat-file -t v0.5.0` 输出 `tag`；`git rev-parse v0.5.0^{commit}` 等于收口提交；
  `grep -x 'version = 0.5.0' ct.pkg` 命中。
- **状态**：**PH-05 收口执行**。远端 tag 推送受 6.5 分支推送约束：收口提交不在远端时不推，见 PH-05 K-3。

### 1.4 更新 D-011 的失效条件

- **为什么**：D-011 现在把「`src/` 布局与安装器不兼容」当成待解缺口；`ns-root` 生效后，
  这条描述就过期了，需要改成「`src/` 布局已由 `ns-root` 满足」，并保留其余失效条件。
- **要做什么**：更新 `docs/decisions/D-011.md` 的「失效条件」与「影响」两节；
  不再要求消费者自算 `-I`，也不再把它登记成包形态缺口。
- **验收**：D-011 含「`src/` 布局已由 `ns-root` 满足」；`bash tools/check.sh g0-decisions` 为 rc=0。
- **状态**：**已由 D-013/D-014 覆盖，不再单独改**。D-011 顶部已标「依赖部分由 D-014 取代」，
  PH-04 卡与状态表已记 R-01 判据 2/3 的去向；不重写 D-011 原文。

## 1.5 能力门槛与落地自查

三项能力已经具备，不再作为挂起理由。落地时仍用同样三句话自查，确认本机工具链真的包含它们：

1. 安装器能从包清单读到 `publisher` 并落 store——安装后能查到包的发布者身份。
2. 编译器把 `ns-root` 自动加入搜索根——删掉手写 `-I src` 后仍能 import。
3. `ct build` 默认读 lock——不传 `-I` 也能解析依赖。

当前自查结果（2026-11-16，`ct v0.58.0`，Darwin）：

1. 安装器读 `publisher` 并落 store：`ct get` 输出 `vendored 1 package(s)`，lock 记录 `ct/fsguard 0.1.0`。
2. 编译器按 `ns-root` 补搜索根：`ct install` 打印 `-I …/fsguard/0.1.0/src`；`ct build main.ct`
   不再报 `cannot resolve import`（**具备**）。
3. `ct build` 默认读 lock：lock 为 `# ct-lock 2`，build 自动用 dev override 解析到本仓（**具备**）。

剩余缺口两条，均属本仓或上沿而非「能力未出现」：`ct build` 未把 `ns-root` 传给 C 编译器，
头包含根要显式 `--cflags "-I<ns-root>"`；`ct install` 仍不校验 import（上游 PKG-6 open），
且对只 import `.m.ct` 的消费者会误报 `cannot resolve import`（本仓 `issues/FSG-02.md`，D-015 规定验收走 `ct build`）。
`rc=0` 不能当解析证明。

## 2 当前实际状态（待决）

### 2.1 `ct.pkg` 的包身份字段

```
$ grep -x 'publisher = ct' ct.pkg
publisher = ct
$ grep -x 'ns-root = src' ct.pkg
ns-root = src
```

- 现状：`publisher` / `ns-root` 已提交；`version = 0.4.0`（PH-04 收口补号），`licence` 为 MIT，
  与 `LICENSE` 及文档表述一致；`requires = ct >= 0.44.1` 未动。
- 处置：已按 1.1 单独提交，工作区其他改动未并入。
- 建议：后续按 1.2 删除手写包含根，再跑消费者验证。

### 2.2 本地备份 tag

```
$ git cat-file -t refs/tags/backup/pre-s4-rollback
commit
$ git show-ref --tags
6f3f40d68a4e38e498aa1b6cb3fc685672ba760f refs/tags/backup/pre-s4-rollback
```

- 现状：轻量 tag（直接指向提交），指向的提交已不在任何分支上，也不是当前 HEAD 的祖先。
- 处置：不删除、不移动、不推送。
- 建议：保留为回滚锚点，直到 1.1～1.3 验证完成；之后由负责人决定删除，或把提交要点抄进
  `docs/reviews/` 后归档。

### 2.3 已过期的挂起说明（留档，不再据此行动）

- PH-04 已按 D-013 收口：R-01 判据 2/3 与 R-02 判据 2 移出，R-03 已落地，R-17 判据 5 登记环境缺口。
- `ns-root` 能力已具备；「目录不上移」是做法，「`ns-root` 提供安装根」是结果，两者一致。
- 本卡已 `closed`，不改写其历史；当前未完成项见 PH-05 卡。

### 2.4 清单外但相邻的一件事

- `ct.pkg` 的 `requires` 仍以编译器版本下限表达，没有改成能力前置；不在上述四件事内，未动。
  是否需要改写，等负责人决定。
- `dep = std@0.3.2` 已按 D-014 提交，`ct.lock` 一并入库；`vendor/` 不进版本库。
  这是 1.1 之外新增的一条依赖声明，验收口径见 D-014（声明即须可解析并记入 lock）。

## 3 落地顺序

0. 更新本机工具链，用 `ct build` 不传 `-I` 跑通任意一个测试，确认三项能力在本机可用。
1. 提交 `ct.pkg` 的 `publisher` / `ns-root`（1.1）。
2. 删除 `tools/check.sh` 与文档示例里的 `-I src` / `-Isrc`（1.2），跑 `bash tools/check.sh all`。
3. 更新 D-011 的失效条件与影响（1.4）。
4. 版本与 tag 一致时打 annotated `v0.1.0`（1.3）。
5. 回看 `backup/pre-s4-rollback` 是否还需要保留。

## 4 本仓的进度判断与下一步

### 4.1 现在完成到什么程度

- 文档认领与重判：四件事的为什么、做什么、怎么验收、当前状态都已写清，本文件即台账。
- 1.1 已落地（`publisher` / `ns-root` 已提交，`ct pkg check` 四条判据全过）。
- 1.2 仍不可开工：C 头包含根仍需显式 `--cflags`，门禁与消费者命令保留该参数。
- 1.3 已由 PH-04 收口覆盖（`v0.4.0` 已打并推送）；PH-05 收口执行 `v0.5.0`。
- 1.4 已由 D-013/D-014 覆盖，不再单独改 D-011。
- 下一个实际动作是 PH-05 的消费者夹具、限定名与 Linux LSan，不再由本文件派生新 phase。

### 4.2 该不该立 phase

**已由 PH-05 承接，不另立打包 phase。** 理由：

1. 1.1 的消费者验收就是 R-01 判据 2/3，PH-05 T-01 直接承接，避免同一验收记两遍。
2. 1.2 的剩余阻塞是上游 `ct build` 不把 `ns-root` 传给 C 编译器，不是本仓可独立完成的能力。
3. 1.3 是每个 phase 收口的固定动作（6.7 V-7），不是独立阶段。

### 4.3 怎么拆步

1. **消费者步**：PH-05 T-01 建 `test/consumer/consumer.ct`，只 import 本包单元，四方法 + 回调断言，接入 `g3-ph05`。
2. **限定名步**：PH-05 T-02 在 `r02_errors.ct` 补裸名/限定名双断言（`ct v0.62.0` 已支持）。
3. **LSan 步**：PH-05 T-03 在 Linux 上跑 `g7-leak` 并回填记录。
4. **收口步**：PH-05 T-04 更新状态表/roadmap/CHANGELOG，版本 0.5.0，打 annotated `v0.5.0`。

PH-04 已收口；以上四步是 PH-05 的范围。

### 4.4 下一步决定

**按 PH-05 卡执行，不再从本文件派生新阶段**：

- T-01 消费者夹具（P-1/P-6 的断尾收口）；
- T-02 限定名断言；
- T-03 Linux LSan 记录；
- T-04 收口与 `v0.5.0`。

1.2 仍未完成，触发条件是上游 `ct build` 把 `ns-root` 传给 C 编译器；未触发前保留显式头包含根。
