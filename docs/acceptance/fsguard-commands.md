# fsguard 判据命令块（R-01…R-17）

> 现状：PH-01 的 R-02、R-05、R-06、R-09 已实现，命令可直接执行；其余条目仍是未实现相的占位，命令行沿用 `ct run` 只是目标态写法（ct 0.44.1 没有 `run` 子命令），轮到所属 phase 时统一改成 `ct build … -I src --cflags "-Isrc" -o /tmp/rNN && /tmp/rNN`。`bash tools/check.sh g1-command` 只做结构校验（每条 R 有 `$ ` 命令 + `rc=`），行为由 `g3-ph01` 执行。

## R-01 包形态与文件分工

```console
$ ct build examples/fsguard/r01_packaging.ct
# rc=0
```

## R-02 错误码枚举

```console
$ bash tools/check.sh g3-ph01 r02
# rc=0
```

## R-03 命名共存

```console
$ ct build examples/fsguard/r03_name_coexist.ct
# rc=0
```

## R-04 分块读

```console
$ ct run test/fsguard/r04_read_chunk.ct
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
$ ct run test/fsguard/r07_walk.ct
# rc=0
```

## R-08 生命周期与所有权

```console
$ ct run test/fsguard/r08_lifecycle.ct
# rc=0
```

## R-09 check 判定顺序

```console
$ bash tools/check.sh g3-ph01 r09
# rc=0
```

## R-10 策略配置

```console
$ ct run test/fsguard/r10_policy.ct
# rc=0
```

## R-11 FsError 契约

```console
$ ct run test/fsguard/r11_error_contract.ct
# rc=0
```

## R-12 读写包装

```console
$ bash tools/check.sh g3-ph02 r12
# rc=0
```

## R-13 FsGuard 遍历

```console
$ ct run test/fsguard/r13_guard_walk.ct
# rc=0
```

## R-14 errno 映射

```console
$ bash tools/check.sh g3-ph02 r14
# rc=0
```

## R-15 POSIX 平台边界

```console
$ ct run test/fsguard/r15_posix.ct
# rc=0
```

## R-16 std::fs 零改动

```console
$ ct run test/fsguard/r16_std_fs_untouched.ct
# rc=0
```

## R-17 夹具与门禁

```console
$ bash tools/check.sh g7-asan
# rc=0
# Linux 追加：ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
```
