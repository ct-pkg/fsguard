# FSG-03 R-17 判据 5 的环境缺口：本机无法启动 Linux 虚拟机，LSan 记录无法产生

id: FSG-03
status: fixed
opened: 2026-11-16
fixed: 2026-11-17（PH-05 T-03，Linux 实测记录回填）
phase: PH-05
severity: minor
rule: R-17 判据 5；`g7-lsan-record` 防呆；D-015 的同类处置（记录缺口，不伪造通过）
anchor: `docs/acceptance/fsguard-status.md` §4 R-17；`docs/reviews/fsguard-ph04-evidence.md` §13；`docs/phases/PH-04/card.md` E-8
evidence: 见 §复现（原始输出）

## 现象

本机为 `Darwin 27.2.0 arm64`，没有可用的 Linux 主机或可启动的 Linux 虚拟机：

- Podman 6.2.0 已安装，`podman machine init` 能下载并初始化 machine，
  但 `podman machine start` 失败：`Error: krunkit exited unexpectedly with exit code 1`。
- 直接用相同参数跑 `krunkit`，在 `VmCreate` 阶段失败：
  `[ERROR krun] Building the microVM failed: Internal(Vm(VmSetup(VmCreate)))`。
- 没有既有 Lima / Colima / Docker 实例；`limactl list` 报 `No instance found`。

因此 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` 无法在 Linux 上执行，
`docs/reviews/fsguard-lsan-linux.md` 无法产生，`g7-lsan-record` 保持红。

## 复现

```console
$ podman machine start
Starting machine "podman-machine-default"
Error: krunkit exited unexpectedly with exit code 1

$ /opt/homebrew/bin/krunkit --cpus 1 --memory 512 --bootloader efi,variable-store=/tmp/fsgpod/data/containers/podman/machine/libkrun/test-efi,create --device virtio-blk,path=/tmp/fsgpod/data/containers/podman/machine/libkrun/podman-machine-default-arm64.raw --device virtio-rng --restful-uri tcp://localhost:64133
[2026-11-16T06:30:04.089927Z ERROR krun] Building the microVM failed: Internal(Vm(VmSetup(VmCreate)))
Error: unable to begin running krun workload

$ limactl list
time="..." level=warning msg="No instance found. Run `limactl create` to create an instance."

$ bash tools/check.sh g7-lsan-record
FAIL: G7:LSAN-RECORD missing docs/reviews/fsguard-lsan-linux.md
```

## 影响

- R-17 判据 5 在本机**未验证**；不得据此宣布 LSan 通过，也不得用 Darwin 的 SKIP 顶替。
- `bash tools/check.sh all` 仍 rc=0（`g7-leak` 在 Darwin 打 SKIP），但 `g7-lsan-record` 单独跑为红。
- PH-04 的收口按「环境缺口已登记」处理，R-17 在状态表保持「部分可验收」；判据 5 的验证方式不变。

## 处置

- 本条只登记缺口，不修改判据、不伪造记录、不把 `g7-lsan-record` 并入 `all`。
- 触发条件已满足（2026-11-17）：用 Lima `vz` 启动 Debian 12（`Linux 6.1.0-54-cloud-arm64 aarch64`，gcc 12.2.0），
  把工作树快照复制到 guest `/tmp/fsg-lsan-repo`，执行
  `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`，输出
  `PASS: g7-leak: Linux ASan+LSan caught the leak`（rc=0）。
- 记录已按模板回填 `docs/reviews/fsguard-lsan-linux.md`（host / date / 命令 / 原始输出 / 环境），
  `bash tools/check.sh g7-lsan-record` rc=0。**本条关闭条件已满足。**
- 本机保留 `/tmp/fsg-lima`、`/tmp/fsg-home`、`/tmp/fsg-lsan*` 等临时目录（可删）；Podman 试验目录 `/tmp/fsgpod` 仍为临时，可删。

## 关闭条件

Linux 上 `g7-leak` 输出 `PASS: g7-leak: Linux ASan+LSan caught the leak` 并已回填
`docs/reviews/fsguard-lsan-linux.md`（`g7-lsan-record` rc=0）。
