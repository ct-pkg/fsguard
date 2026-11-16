# Linux LSan 实测记录（R-17 判据 5）

host: Linux 6.1.0-54-cloud-arm64 aarch64
date: 2026-11-17

command: `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`

## 环境

| 项 | 值 |
| --- | --- |
| 发行版 | Debian GNU/Linux 12 (bookworm) |
| 内核 | `Linux 6.1.0-54-cloud-arm64 aarch64` |
| 编译器 | `cc (Debian 12.2.0-14+deb12u1) 12.2.0` |
| 虚拟机 | Lima `vz`，2 CPU / 2 GiB / 12 GiB |
| 代码快照 | 工作树 `HEAD f1641a8` 的 tar 副本（排除 `.git`、`.ctbuild`），复制到 guest `/tmp/fsg-lsan-repo` |
| 执行方式 | 在 guest 内 `cd /tmp/fsg-lsan-repo` 后直接跑仓库自带 `tools/check.sh`，不替换脚本、不改夹具 |

## 原始输出

```console
$ uname -srm
Linux 6.1.0-54-cloud-arm64 aarch64

$ cc --version
cc (Debian 12.2.0-14+deb12u1) 12.2.0
Copyright (C) 2022 Free Software Foundation, Inc.

$ cd /tmp/fsg-lsan-repo
$ ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
PASS: g7-leak: Linux ASan+LSan caught the leak
rc=0
```

## 说明

- 这条记录证明的是 `g7-leak` 的 Linux 分支：`asan_clean` 在 `detect_leaks=1` 下 rc=0，`leak.c` 被 LeakSanitizer 抓到并非 0 退出。它不替代 Darwin 的 `g7-asan`，也不把 Darwin 的 SKIP 当结论。
- 记录只回填 R-17 判据 5 的缺项，不改 R-17 的判据原文与门禁逻辑。
- 复现时若没有 Linux 主机，按 `docs/reviews/fsguard-lsan-linux.md.tmpl` 重跑；占位符会被 `g7-lsan-record` 判红。
