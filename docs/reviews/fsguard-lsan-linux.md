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

## 第二条记录：Podman 容器独立复核（2026-11-17）

> 这是**独立复核**，用于证明同一门禁在第二个 Linux 环境（容器）里也可复现；
> **不替代**上面的首条记录（Lima/Debian），R-17 判据 5 的结论仍以首条为准。

| 项 | 值 |
| --- | --- |
| host（容器内 `uname -srm`） | `Linux 7.2.11-200.fc44.aarch64 aarch64` |
| 宿主机 | macOS arm64；`podman 6.2.0`（libkrun VM） |
| 镜像 | `docker.io/library/gcc:13`，`--platform linux/arm64` |
| 编译器 | `cc (GCC) 13.5.0` |
| Linux `ct` | 从 ct-lang 源码自举，`ct v0.61.1` |
| 挂载 | `-v <repo>:/w:ro -v <ct-lang>:/src:ro -w /w`（ct-lang 只读，未写入） |
| 自举入口 | `CT_SOURCE_DIR=/src sh /src/install.sh -p /usr/local/bin` |
| 代码快照 | 工作树 `HEAD 0925ec7`，仓库按只读挂载，未在容器内写回 |
| 配方来源 | ct-http `docs/reviews/PH-10/E-P10-1-linux.md` §2（无需改动） |

可照抄命令（宿主机执行，`<repo>` 换成本仓绝对路径）：

```console
$ podman run --rm --platform linux/arm64 \
    -v <repo>:/w:ro \
    -v /Users/samxx/trae-ws/ct-lang:/src:ro \
    -w /w docker.io/library/gcc:13 \
    bash -lc '
      set -e
      CT_SOURCE_DIR=/src sh /src/install.sh -p /usr/local/bin >/tmp/install.log 2>&1
      export CT_BIN=/usr/local/bin/ct
      "$CT_BIN" -v
      uname -srm
      cc --version | head -1
      ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
      echo "g7-leak rc=$?"
    '
```

原始输出：

```console
$ /usr/local/bin/ct -v
ct v0.61.1

$ uname -srm
Linux 7.2.11-200.fc44.aarch64 aarch64

$ cc --version | head -1
cc (GCC) 13.5.0

$ ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
PASS: g7-leak: Linux ASan+LSan caught the leak
g7-leak rc=0
```

说明：

- 与首条记录一样，只跑仓库自带的 `tools/check.sh`，不替换脚本、不改夹具、不改期望。
- 两次记录的结论一致：`asan_clean` 在 `detect_leaks=1` 下 rc=0，`leak.c` 被 LeakSanitizer 抓到并非 0 退出。
- 容器内未执行任何 `git` 写操作；仓库与 ct-lang 均为只读挂载，运行期产物只在容器 `/tmp`。

