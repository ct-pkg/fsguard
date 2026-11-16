# 包根陈旧条目迁移记录（D-016）

> 事由：`ct get std@0.3.1` 被 `~/.ct/pkg/ct/std/0.3.1` 挡住，报摘要不符。
> 裁定：D-016（不删除，整体挪到包根之外的可回退位置并留记录）。
> 备份侧记录：`/Users/samxx/.ct/pkg-backup/20261116/MIGRATION.md`（含回退命令）。

## 1 条目身份

| 项 | 值 |
| --- | --- |
| 原路径 | `/Users/samxx/.ct/pkg/ct/std/0.3.1` |
| 迁移后路径 | `/Users/samxx/.ct/pkg-backup/20261116/ct/std/0.3.1` |
| `ct.pkg` 关键字段 | `name = std`、`publisher = ct`、`version = 0.3.1`、`licence = GPL-3.0-or-later WITH GCC-exception-3.1` |
| 文件数 | 71 |
| 内容摘要（逐文件 sha256 排序后再 sha256） | `aae37735fdec2a5ce03595bb52a7c74f90bfcb379d162aa512a33d6608ca820c` |
| 归档摘要（`tar -cf - -C ~/.ct/pkg/ct/std 0.3.1 \| shasum -a 256`） | `531eacb857d2bf4209e62ee4b00ceb79ab717a6c322b5f2eb8e0f19c3335425e` |

## 2 为什么会被挡住

std 的发布者从 `ct` 改成 `std`，现行可消费的是 `~/.ct/pkg/std/std/0.3.2`
（`publisher = std`、`licence = MIT`）。旧路径上的 `0.3.1` 与索引摘要不一致：

```console
$ ct get std@0.3.1
ctc: store '/Users/samxx/.ct/pkg/ct/std/0.3.1' already exists with a different digest
```

没有任何已安装包声明依赖该条目：

```console
$ grep '^dep' ~/.ct/pkg/*/*/*/ct.pkg
（无命中）
```

## 3 迁移后实测

```console
$ ls ~/.ct/pkg/ct
fsguard http sse token
$ grep -x 'dep = std@0.3.2' ct.pkg
dep = std@0.3.2
$ cat ct.lock
# ct-lock 2
std/std 0.3.2 git https://github.com/ct-pkg/std a3f12172e03a9247ef47dec1dca66309d3111ac2 . sha256:95fc010f704d67e8718574d2419fab48063029c0f9e6cd18961f4e423088ce6d
$ ct install
ct build --ldflags '-lm' <unit>.ct -o build
# lock-format: v2
INSTALL_RC=0
$ ct verify
verified 1 package(s)
VERIFY_RC=0
$ bash tools/check.sh g3-ph04 r03
PASS: g3-ph04: r03 green
```

## 4 回退

```console
$ mkdir -p /Users/samxx/.ct/pkg/ct/std
$ mv /Users/samxx/.ct/pkg-backup/20261116/ct/std/0.3.1 /Users/samxx/.ct/pkg/ct/std/0.3.1
```

回退前核对内容摘要是否仍是 `aae37735…`。保留期限由负责人决定；清理前需更新本文件与备份侧 `MIGRATION.md` 的日期。
