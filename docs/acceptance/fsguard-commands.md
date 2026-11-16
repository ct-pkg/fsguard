# fsguard 判据命令块（R-01…R-17）

> 现状：PH-01…PH-05 的实现与门禁已就位，下面每条命令都直接指向现行 `tools/check.sh` 子命令；`ct run` 已不存在，不要照旧写法执行。`bash tools/check.sh g1-command` 只做结构校验（每条 R 有 `$ ` 命令 + `rc=`），行为由对应的 `g3-ph*` 执行。

## R-01 包形态与文件分工

```console
$ bash tools/check.sh g3-ph04 all
# rc=0
# 判据 1/4：包内无 `pub trait … for char *`，.h.ct/.m.ct 无 #define。
$ bash tools/check.sh g3-ph05 consumer
# rc=0
# 判据 2/3：消费者只 import 本包单元，四方法 + FsWalkCb 实际调用并断言。
```

## R-02 错误码枚举

```console
$ bash tools/check.sh g3-ph01 r02
# rc=0
# 裸名与限定名 FsErrCode::FS_ERR_* 分别取值并断言（ct v0.62.0）。
```

## R-03 命名共存

```console
$ bash tools/check.sh g3-ph04 r03
# rc=0
# 判据 1/2：r03_coexist；判据 3：r03_qualified + r03_ambiguous（未限定必须歧义）。
$ bash tools/check.sh g3-ph04 all
# rc=0
# 判据 4：四名与 std 22 名交集为空。
```

## R-04 分块读

```console
$ bash tools/check.sh g3-ph02 r04
# rc=0
```

## R-05 词法规范化

```console
$ bash tools/check.sh g3-ph01 r05
# rc=0
```

## R-06 段边界判定

```console
$ bash tools/check.sh g3-ph01 r06
# rc=0
```

## R-07 遍历与深度

```console
$ bash tools/check.sh g3-ph03 r07
# rc=0
```

## R-08 生命周期与所有权

```console
$ bash tools/check.sh g3-ph02 r08
# rc=0
```

## R-09 check 判定顺序

```console
$ bash tools/check.sh g3-ph01 r09
# rc=0
```

## R-10 策略配置

```console
$ bash tools/check.sh g3-ph03 r10
# rc=0
```

## R-11 FsError 契约

```console
$ bash tools/check.sh g3-ph02 r11
# rc=0
```

## R-12 读写包装

```console
$ bash tools/check.sh g3-ph02 r12
# rc=0
```

## R-13 FsGuard 遍历

```console
$ bash tools/check.sh g3-ph03 r13
# rc=0
```

## R-14 errno 映射

```console
$ bash tools/check.sh g3-ph02 r14
# rc=0
```

## R-15 POSIX 平台边界

```console
$ bash tools/check.sh g3-ph04 r15
# rc=0
# `a\b` 按字面保留：不转 `/`、不作段边界、驱动器形式不解析；src 内无 Win32 分支。
```

## R-16 std::fs 零改动

```console
$ bash tools/check.sh g3-ph04 all
# rc=0
# README「能力对照表」与本包符号一一对应；char * 上只有四个本包方法名。
$ git -C <ct-pkg/std> status --porcelain
# rc=0，输出为空（std 侧只读核对；本仓不使用也不修改 std）
```

## R-17 夹具与门禁

```console
$ bash tools/check.sh g7-asan
# rc=0
# Darwin: bash tools/check.sh g7-leak
# SKIP（无 LSan），rc=0
# Linux: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
# PASS: g7-leak: Linux ASan+LSan caught the leak
$ bash tools/check.sh g7-lsan-record
# rc=0（记录见 docs/reviews/fsguard-lsan-linux.md）
```

## 附：与 std 的语义差异（D-011 / D-014）

fsguard 与 `ct-pkg/std` 是兄弟包。**依赖口径按 D-014**：`ct.pkg` 声明 `dep = std@0.3.2`，
解析结果记入 `ct.lock`；`vendor/` 不进版本库，构建时包含根由包根提供
（`~/.ct/pkg/std/std/0.3.2/std/**`）。门禁校验的是「声明了就必须可解析并记入 lock」，
不要求「必须有 std 依赖」。两者可在同一编译单元共存，`char *` 方法名不冲突。以下差异按 std 实测口径记录，
**不得当成等价实现互相替换**：

| 项 | `std::fs` / `std::io` | fsguard | 归属 |
| --- | --- | --- | --- |
| 读目录 | `readFile` 返回 0 | `FS_ERR_IS_DIR` | fsguard 对；std 已知缺口（S-1） |
| 失败分类 | 统一 `-1`（`open` 为 NULL） | `FS_ERR_NOT_FOUND` / `PERMISSION` / `IS_DIR` / … | fsguard；R-14 依赖 |
| 二进制写 | `writeFile` 按 `strlen`，不能含 NUL | `write_file(path, data, len)` 按 `len` | fsguard；R-12/D-006 依赖 |
| offset 读 | 无 `seek` | `read_chunk(path, offset, buf, len)` | fsguard |
| 目录遍历 | `list` 单层、`\n` 拼接、无类型 | `walk` 递归、`is_dir`、可剪枝 | fsguard |
| 路径规范化 / 段边界 | 无（只有 `std::str` 字节方法） | `normalize_to` / `is_under` | fsguard |
| 存在性 / 单层便捷列目录 / 整文件替换 | `exists` / `list` / `writeFile` | 不提供 | std |

路径语义与递归遍历留在 fsguard 的理由：它们与 `check`、`FS_ERR_*`、deny 剪枝同属策略层；
std 的定位是「四个整文件/单层原语」，把策略语义塞回 std 会让 std 承担错误码与遍历策略。
对 std 的能力建议（读目录返 0、按 `strlen` 写、errno、mkdir/remove/rename、offset 读、以及
「路径规范化/段边界/递归遍历不进 std」的反向结论）已整理成可直接投递的文本：
`docs/reviews/fsguard-std-suggestions.md`。不改 std 仓库。
