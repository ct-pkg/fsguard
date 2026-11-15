# fsguard 手工验证清单（不进 CI）

> 对应 D-012 与 `docs/reviews/fsguard-fsr-battle.md`（B-001）。
> 这里只记录**无法稳定自动化**的验证；FSR-02/03 的负例已由 `bash tools/check.sh g3-ph04 r18` 覆盖。

## FSR-04 挂载点 / 绑定挂载

前提：`check` 是词法策略，不比较 `st_dev`；本清单验证「根内路径实际来自另一个文件系统时，包照读」。**不防护**，只记录事实。

### A. Darwin：`hdiutil` 弱变体（weaker variant）

说明：这不是 bind mount，只是把一个新卷挂到根内；**不等价于把根外已有目录 bind 进来**，只证明 `st_dev` 变化不被检测。

```console
$ mkdir -p /tmp/fsr_battle/root/mnt /tmp/fsr_battle/outside
$ cd /tmp/fsr_battle
$ hdiutil create -size 8m -fs HFS+ -volname fsrbat -quiet t.dmg
$ hdiutil attach -nobrowse -mountpoint /tmp/fsr_battle/root/mnt t.dmg
$ printf 'OUTSIDE-MOUNT\n' > /tmp/fsr_battle/root/mnt/secret.txt
$ stat -f 'mnt dev=%d' /tmp/fsr_battle/root/mnt      # 与根目录 st_dev 不同
$ /tmp/fsr_battle/mountread                          # 探针：check + read_file
check_mount=0 read_mount=14 content=OUTSIDE-MOUNT
$ hdiutil detach /tmp/fsr_battle/root/mnt
```

判读：`check_mount=0`（词法通过）、`read_mount=14`（读到 14 字节 `OUTSIDE-MOUNT\n`）即为「未防护」成立。若探针输出不同，说明行为变了，先重开 D-012。

### B. macOS：真正的 bind mount

```console
$ mkdir -p /tmp/fsr_battle/root/mnt
$ mount -t nullfs /tmp/fsr_battle/outside /tmp/fsr_battle/root/mnt
```

本机实测失败（2026-11-15，Darwin 27.2.0）：

```console
mount: exec /Library/Filesystems/nullfs.fs/Contents/Resources/mount_nullfs for /private/tmp/fsr_battle/root/mnt: No such file or directory
mount: /private/tmp/fsr_battle/root/mnt failed with 72
```

缺的是 `nullfs` 支持（`mount_nullfs` 不存在）与 root 权限，不是脚本问题。若目标机器有 `mount_nullfs`，用 `sudo mount_nullfs <outside> <root>/mnt` 复跑 A 的探针。

### C. Linux：`mount --bind`

需要 root 或 `CAP_SYS_ADMIN`：

```console
$ mkdir -p /tmp/fsr_battle/root/mnt
$ sudo mount --bind /tmp/fsr_battle/outside /tmp/fsr_battle/root/mnt
$ ./mountread        # 期望 check_mount=0, read_mount 读到根外内容
$ sudo umount /tmp/fsr_battle/root/mnt
```

user namespace 变体（是否可行取决于内核是否允许非特权 userns）：

```console
$ unshare -r -m sh -c 'mount --bind /tmp/fsr_battle/outside /tmp/fsr_battle/root/mnt && ./mountread'
```

若 `unshare` 被禁用或 bind mount 返回 `EPERM`，按「本机不具备特权」记录，不得记通过。

### 记录格式

每次手工执行后追加一行：

| 日期 | 主机/内核 | 方式 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-11-15 | Darwin 27.2.0 arm64 | `hdiutil` 弱变体 | `check=0, read=14, OUTSIDE-MOUNT` | weaker variant，不等价于 bind mount |
| 2026-11-15 | Darwin 27.2.0 arm64 | `mount_nullfs` | 失败 rc=72（nullfs 缺失） | 需 nullfs + root |
