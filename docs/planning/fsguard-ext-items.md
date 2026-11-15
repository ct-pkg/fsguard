# fsguard 包外事项认领（EXT-FSG）

> 来源：CT 仓迁出的包外事项（提案 §10 S4；CT 侧 PKG-2 历史记录）。
> 本仓只做**文档认领与状态登记**：不改 `ct.pkg` 的 `publisher` / `ns-root`、不打 tag、不动版本号。
> 本文只引用能力前置（C1/C2/C3），不引用编译器版本号。

## 0 能力前置

| 代号 | 能力 | 当前状态 | 本仓可核对的事实 |
| --- | --- | --- | --- |
| C1 | `ct get` 落 store 并读取包的 `publisher` | 未满足 | `ct.pkg` 工作区草稿已写 `publisher = ct`，尚未提交，也没有 store 侧消费证据 |
| C2 | `ns-root` 进入 `-I` | 未满足 | 工作区草稿已写 `ns-root = src`；门禁仍显式传 `-I src` 与 `--cflags "-Isrc"` |
| C3 | `ct build` 默认读 lock | 未满足 | 门禁与示例仍显式传 `-I` |

## 1 认领表

四条全部认领；**当前 0 条实施**，全部等前置能力。

| ID | 来源 | 要做什么 | 前置 | 验收方式 | 状态 |
| --- | --- | --- | --- | --- | --- |
| EXT-FSG-01 | 提案 §10 S4 | `ct.pkg` 补 `publisher = ct`、`ns-root = src` | C1、C2 | `git diff ct.pkg` 只含这两行；`grep -x 'publisher = ct' ct.pkg`、`grep -x 'ns-root = src' ct.pkg` 均命中；消费者用 `ct get` 后无需手写 `-I` 即可 import | 认领，待前置；工作区已有草稿（未提交） |
| EXT-FSG-02 | 提案 §10 S4 | 去掉 `-Isrc`，由 `ns-root` 推导 | C2 | `ct.pkg` 不新增 `cflags`；`grep -rn -- '-Isrc' tools/check.sh` 为 0 命中；消费者构建命令不再需要 `-I src` | 认领，待前置；`ct.pkg` 当前无 `cflags` 字段，`-Isrc` 目前只在门禁命令与历史证据里 |
| EXT-FSG-03 | 提案 §10 S4 | 打 `v0.1.0` tag | C1、C2（包身份与安装根定稿） | annotated tag：`git cat-file -t v0.1.0` 为 `tag`；默认分支可达：`git merge-base --is-ancestor v0.1.0 <默认分支>` 为真；`ct.pkg` 的 `version` 与 tag 一致 | 认领，未打 tag |
| EXT-FSG-04 | 提案 §10 S4；CT 侧 PKG-2 历史记录 | 更新 D-011：`src/` 布局已由 `ns-root` 满足，标注失效条件 | C2 | D-011 的「失效条件 / 影响」含「`src/` 布局已由 `ns-root` 满足」；不再要求消费者自算 `-I`；`g0-decisions` 仍绿 | 认领，未改；D-011 现文仍写「`ct install` 不兼容 `src/` 布局」 |

## 2 本仓当前实际状态（待决）

### 2.1 工作区未提交的 `ct.pkg` 改动

```
$ git status --short
 M ct.pkg

$ git diff -- ct.pkg
+publisher = ct
+ns-root = src
```

- 现状：只存在于工作区，未暂存、未提交；`version`、`licence`、`requires` 未动。
- 处置：**本轮不提交、不丢弃**。前置能力（C1/C2）满足前保持原样。
- 建议：C1/C2 满足后，与 EXT-FSG-02、EXT-FSG-03 一起提交（同一提交内完成包身份、安装根与 tag 的配套），再打 annotated `v0.1.0`；若届时决定不采用，允许单独回退这两行。

### 2.2 `backup/pre-s4-rollback` tag

```
$ git cat-file -t refs/tags/backup/pre-s4-rollback
commit
$ git show-ref --tags
6f3f40d68a4e38e498aa1b6cb3fc685672ba760f refs/tags/backup/pre-s4-rollback
$ git log -1 --format='%H %ci %s' 6f3f40d
6f3f40d… 2026-11-15 21:06:36 +0800 chore(pkg): align ct.pkg with shared-store identity
```

- 现状：**轻量 tag**（直接指向 commit，不是 tag 对象）；指向的提交不在任何分支上，也不是当前 HEAD 的祖先（已被 reset 掉）。
- 处置：**不删除、不移动、不推送**。
- 建议：保留为回滚锚点，直到 EXT-FSG-01…03 落地并验证；之后由 owner 决定删除，或把提交要点抄进 `docs/reviews/` 后归档。

### 2.3 `PH-04/card.md` 的挂起说明自相矛盾

- 位置一：[card.md](../phases/PH-04/card.md)「范围 → 不做什么」写着「不把命名空间目录上移到仓库根（`ct install` 的 `src/` 布局缺口只登记）」。
- 位置二：同卡「后半」R-01 写着「等 `ns-root`/包机制能标准安装」。
- 矛盾：`ns-root = src` 正是用**不上移目录**的方式补齐安装根；一处把 `src/` 布局当缺口，另一处等 `ns-root` 解决它，两句话对同一事实给出相反判断。
- 处置：本轮不改卡（属于 owner 决策），只登记。
- 建议（二选一）：
  - A. 保留「不上移目录」，把括号理由改成「由 `ns-root` 推导 `-I`，目录保持 `src/`」；
  - B. 删除「不上移目录」这一条，只保留后半的「等 `ns-root`」。

### 2.4 清单外但相邻的一件事

- `ct.pkg` 的 `requires` 仍以编译器版本下限表达，没有改成能力前置；本清单未覆盖，未动。是否需要改写，等 owner 决定。

## 3 前置满足后的执行顺序（供 owner 拍板）

1. C1/C2 落地后：提交 `ct.pkg` 的 `publisher` / `ns-root`（EXT-FSG-01）。
2. 同一轮去掉门禁与文档里的 `-Isrc`（EXT-FSG-02），跑 `bash tools/check.sh all`。
3. 更新 D-011 的失效条件与影响（EXT-FSG-04）。
4. 版本与 tag 一致时打 annotated `v0.1.0`（EXT-FSG-03）。
5. 回看 `backup/pre-s4-rollback` 是否还需要保留。
