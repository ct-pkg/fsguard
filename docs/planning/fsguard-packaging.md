# fsguard 包安装与发布前置

本仓的单元在 `src/fsguard/`，包清单只写了 `name = fsguard`。消费者通过包管理器安装后，
安装器只按包名给出一个包含根，实际会报 `cannot resolve import 'fsguard/FsGuard'`。
下面四件事是把「装上就能 import」和「可发布」补齐，全部**未实施**，等包管理器与编译器具备相应能力。

## 1 要做的四件事

### 1.1 包清单声明发布者与命名空间根

- **为什么**：消费者不应自己推算 `-I`；包清单需要说明「谁发布」以及「命名空间根在哪一层」。
  否则安装结果与源码布局对不上，消费者必失败。
- **要做什么**：`ct.pkg` 增加 `publisher = ct`、`ns-root = src`。工作区已有这两行草稿，尚未提交。
- **验收**：`grep -x 'publisher = ct' ct.pkg`、`grep -x 'ns-root = src' ct.pkg` 均命中；
  一个最小消费者只走包管理器安装、不手写任何 `-I`，能 import `fsguard::FsGuardOps`。
- **状态**：挂起，等 1.5 的判断条件成立。

### 1.2 构建命令不再手写包含根

- **为什么**：`ct.pkg` 没有 `cflags` 字段，`-Isrc` 实际上是写在构建命令里的：
  `tools/check.sh` 有 4 处 `ct build … -I src --cflags "-Isrc"`，文档示例也照抄了它。
  这些手写参数让测试用源码根、消费者用安装根，两条路径不一致，门禁会掩盖真实的安装问题。
- **要做什么**：编译器能按 `ns-root` 自动加入搜索根之后，删掉 `tools/check.sh` 四处的
  `-I src` 与 `--cflags "-Isrc"`，并同步修正文档示例里的同样写法；`ct.pkg` 不新增 `cflags` 字段。
- **验收**：`grep -rn -- '-Isrc' tools/check.sh` 为 0 命中；`bash tools/check.sh all` 仍为 rc=0；
  消费者侧仍能只靠包管理器安装完成 import。
- **状态**：挂起，等 1.5 的判断条件成立。

### 1.3 打 `v0.1.0` tag

- **为什么**：`ct.pkg` 的 `version` 已是 `0.1.0`，但仓库没有对应 tag，发布点不可核对。
- **要做什么**：在包身份与安装根定稿后打 annotated `v0.1.0`，tag 落在默认分支可达的提交上，
  且 `ct.pkg` 的 `version` 与 tag 名一致。
- **验收**：`git cat-file -t v0.1.0` 输出 `tag`（annotated，不是轻量）；
  `git merge-base --is-ancestor v0.1.0 <默认分支>` 为真；`grep -x 'version = 0.1.0' ct.pkg` 命中。
- **状态**：未打 tag。

### 1.4 更新 D-011 的失效条件

- **为什么**：D-011 现在把「`src/` 布局与安装器不兼容」当成待解缺口；一旦 `ns-root` 生效，
  这条描述就过期了，需要改成「`src/` 布局已由 `ns-root` 满足」，并保留其余失效条件。
- **要做什么**：更新 `docs/decisions/D-011.md` 的「失效条件」与「影响」两节；
  不再要求消费者自算 `-I`，也不再把它登记成包形态缺口。
- **验收**：D-011 含「`src/` 布局已由 `ns-root` 满足」；`bash tools/check.sh g0-decisions` 为 rc=0。
- **状态**：未改，等 1.5 的判断条件成立。

## 1.5 怎么判断前置能力已经具备

不用等别的仓通知，本仓用三句话自查；任一句不成立，1.1 / 1.2 / 1.4 保持挂起：

1. 安装器能从包清单读到 `publisher` 并落 store——安装后能查到包的发布者身份。
2. 编译器把 `ns-root` 自动加入搜索根——删掉手写 `-I src` 后仍能 import。
3. `ct build` 默认读 lock——不传 `-I` 也能解析依赖。

当前自查结果：三条都不成立（`tools/check.sh` 仍在手写 `-I src`，消费者仍报
`cannot resolve import 'fsguard/FsGuard'`）。

## 2 当前实际状态（待决）

### 2.1 工作区未提交的 `ct.pkg` 改动

```
$ git status --short
 M ct.pkg

$ git diff -- ct.pkg
+publisher = ct
+ns-root = src
```

- 现状：只在工作区，未暂存、未提交；`version`、`licence`、`requires` 未动。
- 处置：本轮不提交、不丢弃。等 1.5 的三条成立前保持原样。
- 建议：三条成立后，与 1.2、1.3 一起提交（包身份、安装根、发布点配套），再打 annotated `v0.1.0`；
  若届时不采用，只回退这两行即可。

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

### 2.3 `PH-04/card.md` 的挂起说明自相矛盾

- 位置一：[card.md](../phases/PH-04/card.md)「范围 → 不做什么」写着
  「不把命名空间目录上移到仓库根（`ct install` 的 `src/` 布局缺口只登记）」。
- 位置二：同卡「后半」R-01 写着「等 `ns-root`/包机制能标准安装」。
- 矛盾：`ns-root = src` 正是用**不上移目录**的方式补齐安装根；一处把 `src/` 布局当缺口，
  另一处等 `ns-root` 解决它，两句话对同一事实给出相反判断。
- 处置：本轮不改卡（属负责人决策），只登记。
- 建议（二选一）：
  - A. 保留「不上移目录」，把括号理由改成「由 `ns-root` 推导 `-I`，目录保持 `src/`」；
  - B. 删除「不上移目录」这一条，只保留后半的「等 `ns-root`」。

### 2.4 清单外但相邻的一件事

- `ct.pkg` 的 `requires` 仍以编译器版本下限表达，没有改成能力前置；不在上述四件事内，未动。
  是否需要改写，等负责人决定。

## 3 前置满足后的顺序

1. 自查 1.5 三条全部成立。
2. 提交 `ct.pkg` 的 `publisher` / `ns-root`（1.1）。
3. 删除 `tools/check.sh` 与文档示例里的 `-I src` / `-Isrc`（1.2），跑 `bash tools/check.sh all`。
4. 更新 D-011 的失效条件与影响（1.4）。
5. 版本与 tag 一致时打 annotated `v0.1.0`（1.3）。
6. 回看 `backup/pre-s4-rollback` 是否还需要保留。
