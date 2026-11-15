# FSR-02/03/04 负例可行性 battle（B-001）

> battle_id: B-001
> scope: FSR-02（TOCTOU 换链接）、FSR-03（硬链接越界）、FSR-04（挂载点/绑定）
> source: `docs/decisions/D-012.md`、`docs/analysis.md` §3.8、`docs/reviews/fsguard-verdict.md`（FSR-02/03/04）
> date: 2026-11-15
> host: Darwin 27.2.0 arm64（APFS，`/tmp`）；`ct` v0.53.0
> discipline: 只出结论与实测，不写实现；本地提交文档，不 push、不打 tag

## 0 结论摘要

| FSR | Darwin 无特权复现 | Linux 复现 | 结论 |
| --- | --- | --- | --- |
| FSR-02 TOCTOU | **能**：`check=0` 后换软链，`read_file` 读到根外内容 | 未实测（本机无 Linux 运行时）；POSIX 语义相同，预计能 | **进普通门禁**，测试断言「绕过成立」 |
| FSR-03 硬链接 | **能**：`link=0` 后 `read_file` 读到根外内容 | 未实测；`link(2)` 不需 root，同一文件系统即可，预计能 | **进普通门禁**，测试断言「绕过成立」 |
| FSR-04 挂载点 | **部分**：`hdiutil` 挂 DMG 到 `root/mnt` 成功，读到 `OUTSIDE-MOUNT`；真正的 bind mount 不可（`mount_nullfs` 缺失） | 未实测；`mount --bind` 需 root / `CAP_SYS_ADMIN` | **只写文档 + 手工验证清单**，不进 CI |

一句话：**02/03 用「断言绕过确实发生」的负例进普通门禁；04 只写边界与手工步骤。**

## 1 环境与限制

- 本机只有 Darwin；没有 Linux 运行时：

```console
$ command -v docker podman lima limactl colima multipass nerdctl qemu-system-aarch64 tart incus lxc
（无输出）
$ ls /Applications | grep -i -E 'docker|utm|orb|lima'
（无输出）
```

- 因此三条的 Linux 结论都标「未实测」。要补测只需一台普通 Linux（非 root）即可跑 02/03；04 需要 root 或开启 unprivileged user namespace。
- 所有夹具在 `/tmp/fsr_battle`，探针用 `ct build <probe>.ct -I src --cflags "-Isrc"` 编译，链接仓库当前 `src/fsguard`。

## 2 实测记录

### 2.1 FSR-02 TOCTOU：`check` 通过后换软链

探针逻辑（`/tmp/fsr_battle/toctou.ct`）：

```ct
FsGuard *g = fsguard::fsguard_new("/tmp/fsr_battle/root");
mkdir("/tmp/fsr_battle/root/dir", 0755);
rc_check = g->check("/tmp/fsr_battle/root/dir/secret.txt");   // 词法通过
rmdir("/tmp/fsr_battle/root/dir");
symlink("/tmp/fsr_battle/outside", "/tmp/fsr_battle/root/dir"); // 换成根外软链
rc_read = g->read_file("/tmp/fsr_battle/root/dir/secret.txt", buf, 128);
```

实测输出：

```console
$ /tmp/fsr_battle/toctou
check_before_swap=0
read_after_swap=15 content=OUTSIDE-TOCTOU
```

- `0` 是 `FS_OK`；`15` 是字节数，内容是根外文件 `OUTSIDE-TOCTOU`。
- 注意：`read_file` **内部还会再跑一次词法 `check`**，同样通过；绕过不是「跳过检查」，而是「词法检查看不出软链，`open` 跟随了它」。
- `check` 是纯字符串比较，换链接与检查之间没有任何文件系统校验。

### 2.2 FSR-03 硬链接：根内名字指向根外 inode

探针逻辑（`/tmp/fsr_battle/hardlink.ct`）：

```ct
rc_link = link("/tmp/fsr_battle/outside/hard.txt", "/tmp/fsr_battle/root/link.txt");
rc_read = g->read_file("/tmp/fsr_battle/root/link.txt", buf, 128);
```

实测输出：

```console
$ /tmp/fsr_battle/hardlink
link_rc=0
read_hardlink=17 content=OUTSIDE-HARDLINK
```

- macOS APFS 上，只要同一卷且有目标目录写权限，`link(2)` 不需要 root；`/tmp` 不受 SIP 影响，未出现权限错误。
- `check` 看到的是 `/tmp/fsr_battle/root/link.txt`，词法完全在根内；inode 指向根外，包不比较 `st_ino` / `st_nlink`。

### 2.3 FSR-04 挂载点：bind mount 不可，DMG 挂载可复现

真正的 bind mount（把根外已存在目录挂到根内）：

```console
$ mkdir -p /tmp/fsr_battle/root/mnt
$ mount -t nullfs /tmp/fsr_battle/outside /tmp/fsr_battle/root/mnt
mount: exec /Library/Filesystems/nullfs.fs/Contents/Resources/mount_nullfs for /private/tmp/fsr_battle/root/mnt: No such file or directory
mount: /private/tmp/fsr_battle/root/mnt failed with 72
mount_rc=72
```

- 本机没有 `nullfs` 文件系统；macOS 的 bind mount 走 `mount_nullfs`，通常还需要 root。缺的是 nullfs 支持 + 特权，不是脚本问题。

退一步用 `hdiutil` 把一个 DMG 挂到根内（不需要 root，也不需要 loop 设备）：

```console
$ hdiutil create -size 8m -fs HFS+ -volname fsrbat -quiet t.dmg
$ hdiutil attach -nobrowse -mountpoint /tmp/fsr_battle/root/mnt t.dmg
/dev/disk4s1  Apple_HFS  /private/tmp/fsr_battle/root/mnt
attach_rc=0
$ printf 'OUTSIDE-MOUNT\n' > /tmp/fsr_battle/root/mnt/secret.txt
$ stat -f 'mnt dev=%d' /tmp/fsr_battle/root/mnt
mnt dev=16777237
$ /tmp/fsr_battle/mountread
check_mount=0 read_mount=14 content=OUTSIDE-MOUNT
```

- 根与挂载点 `st_dev` 不同（`16777231` vs `16777237`），说明路径在根下、实际是另一个文件系统；fsguard 不做 `st_dev` 比较，照读。
- 这**不是**「把根外已有目录 bind 进来」的等价复现，只是「在根内挂一个新卷」；结论必须按这个 weaker variant 写，不能冒充 bind mount。

### 2.4 Linux：未实测，补测命令

普通用户、同一文件系统：

```console
$ gcc -o toctou toctou.c # 或用仓库内 ct 探针
$ ./toctou               # 期望 check=0, read 读到 OUTSIDE-TOCTOU
$ ./hardlink             # 期望 link=0, read 读到 OUTSIDE-HARDLINK
```

FSR-04：

```console
$ mkdir -p root/mnt
$ sudo mount --bind outside root/mnt    # 需要 root / CAP_SYS_ADMIN
# 或：unshare -r -m 后在 user namespace 内尝试；取决于内核允许
```

本机没有 Linux，上述输出为空缺，不能当成「Linux 已验证」。

## 3 判据怎么写

两种写法都会把人带偏，必须选一种并把「它证明了什么」写死。

| 写法 | 示例断言 | 它固化的是什么 | 会把人带偏成什么 |
| --- | --- | --- | --- |
| A 断言「绕过成立」 | `check==FS_OK` 且 `read_file` 返回根外字节；用例名 `known_bypass_*` | 「这里现在确实能绕过去」的已知限制 | 若读者只看绿灯不看名字，会以为「测试覆盖了威胁 = 已防护」；若将来有人加了防护，用例转红，会被误当成回归而删掉 |
| B 断言「绕过被拒绝」 | `check==FS_OK` 后 `read_file != SUCCESS` 或内容不是根外 | 一个**尚不存在**的防护承诺 | 今天必红，只能标 TODO/xfail/skip；长期红会被无视，或被人为了让 CI 绿而删掉；一旦某天因权限变化偶然变绿，会误报「已修复」 |

推荐：**02/03 用 A**，但加三条硬约束，避免变成「把不安全固化成契约」：

1. 用例名与断言文案必须带 `known_bypass` / `not_mitigated`，文件头写明「这是已知绕过，不是安全保证；若用例失败，说明行为变了，先重开 D-012 再改用例」。
2. 断言必须落到**根外内容本身**（字节数与内容都断），不能只断返回值；只断返回码会被平台差异骗过。
3. 这类用例独立成一个测试文件（如 `r18_known_bypass.ct`），不与「应当成功/应当拒绝」的常规用例混在一起；门禁输出里能看到 `known_bypass` 字样。

04 不建议写成门禁用例：bind mount 需要特权或平台特性，CI 会假红/假绿；用**文档 + 手工清单**，判据写成「文档列出未防护并给出可复现步骤」，不是「运行时拒绝」。

## 4 反对意见与反驳

| # | 反对「写负例」 | 反驳 |
| --- | --- | --- |
| O-1 | 脆弱的特权用例会污染门禁 | 02/03 不需要特权，Darwin/Linux 普通用户都能跑；04 正是因此不进 CI，只写手工清单 |
| O-2 | 把不安全行为固化成契约 | 契约已经由 D-012 写死为「不防护」；用例固化的是**已知限制**，不是功能承诺。失败即提示「行为变了」，比沉默更安全 |
| O-3 | 平台差异导致 CI 假红 | 02/03 是 POSIX 语义；硬链接在 FAT/exFAT 等不支持的文件系统上会 `EPERM/EOPNOTSUPP`。约定：`link()` 返回这些错误时打印明确 `SKIP: hardlink unsupported on this fs`，**不算通过**；CI 固定用 ext4/tmpfs/APFS |
| O-4 | 负例会教坏读者 | 用例名、文件头、README 边界行、D-012 四处同时否定「安全边界」；比只写文档更难被误读 |
| O-5 | 负例没有维护价值 | 它能在有人无意中加防护/改语义时立刻变红，强制重新裁定；成本是一个测试文件 |
| O-6 | 04 的 DMG 挂载也能跑，为什么不进 CI | 它只证明「根内出现另一个文件系统」，不证明 bind mount；macOS 与 Linux 路径完全不同，放进 CI 会制造「已覆盖挂载点」的错觉 |

## 5 不写测试时靠什么防误用

- `D-012` 是唯一裁定，README 边界行与状态表都指向它；
- 状态表 §2 已把 02/03/04 标为「非目标（D-012）」，不是「待实现」；
- 若 04 只写文档，建议在状态表附一条「手工验证清单」链接，列出 `mount_nullfs` / `mount --bind` 的具体步骤与所需权限；
- 下游若要安全隔离，只能上 `openat(O_NOFOLLOW)` / 权限模型 / 容器，不能引用本包的 `check`。

## 6 可执行方案

| FSR | 去向 | 判据写法 | 备注 |
| --- | --- | --- | --- |
| FSR-02 | 普通门禁（PH-04 新增 `r18_known_bypass`） | 断言 `check==FS_OK` 且 `read_file` 读到的字节/内容等于根外哨兵 | 用例名与注释带 `known_bypass`；失败先重开 D-012 |
| FSR-03 | 普通门禁（同上） | 断言 `link()==0` 且 `read_file` 读到根外哨兵 | 文件系统不支持硬链接时显式 SKIP（不算通过） |
| FSR-04 | 文档 + 手工验证清单 | 文档判据：写明 bind mount 需 root/CAP_SYS_ADMIN、macOS 需 nullfs；不写运行时断言 | 可选记录 Darwin `hdiutil` weaker variant，但标注不等价 |

## 7 仍需负责人决定

1. 是否接受「断言绕过成立」的负例进入普通门禁（本记录推荐接受；这是唯一能防止「绿灯 = 已防护」误读的机械手段）。
2. 04 是否要把 Darwin `hdiutil` 的 weaker variant 写进手工清单（建议写，但明确不等于 bind mount）。
3. Linux 实测缺口：02/03 需一台普通 Linux 复跑；04 需 root 或 userns。补测前，Linux 列只能记「未实测」。

## 8 原始输出汇总

```console
$ /tmp/fsr_battle/toctou
check_before_swap=0
read_after_swap=15 content=OUTSIDE-TOCTOU

$ /tmp/fsr_battle/hardlink
link_rc=0
read_hardlink=17 content=OUTSIDE-HARDLINK

$ mount -t nullfs /tmp/fsr_battle/outside /tmp/fsr_battle/root/mnt
mount: exec /Library/Filesystems/nullfs.fs/Contents/Resources/mount_nullfs for /private/tmp/fsr_battle/root/mnt: No such file or directory
mount: /private/tmp/fsr_battle/root/mnt failed with 72

$ /tmp/fsr_battle/mountread
check_mount=0 read_mount=14 content=OUTSIDE-MOUNT
```
