# ct-fsguard 包设计提案

> 以下为提案原文，正文未删改。

需要在 CT-PKG 下面创建一个新包，已经在服务器和 GitHub 上创建好了。下面是提案，你需要帮我在本地的 workspace 上创建这个包的项目，这次跟之前不同，不在 CT language 下面。ct-fsguard 包设计提案

1 定位

构建在 std::fs 之上的策略感知文件系统层。不是 std::fs 的替代品。

能力 std::fs（已有） ct-fsguard（本包）
基础读写 exists / readFile / writeFile 内部调用 std::fs，不重复实现
目录列举 list（仅列目录） 递归 walk（深度限制、过滤回调）
路径处理 无 normalize_to / is_under / 沙箱校验
大文件 一次性读入 read_chunk 按 offset 分块
错误 状态码 结构化 FsError（分类 + 路径 + 原因）
访问策略 无 可选 allow_prefix / deny_pattern / 根路径约束

通用性：路径沙箱、分块读、结构化错误、递归遍历在任何需要受控文件访问的 CT 项目里都成立。Agent 内核是第一个消费者，不是唯一消费者。策略层可选——不配置时退化为 std::fs 的增强版。

非目标：文件锁、内存映射、异步 I/O、watch/notify、符号链接解析、ACL、跨平台路径自动统一。

---

2 API 分层

2.1 无状态原语 → 挂 char * 宿主

```ct
pub trait FsGuardOps for char * {
    int read_chunk(long offset, char *buf, int len);   // 返回字节数或 -1
    int normalize_to(char *out, int cap);              // 返回 0 或 -1
    int walk(FsWalkCb cb, void *ud);                   // 返回 0 或回调值
    int is_under(char *prefix);                        // 1 是 / 0 否
}

pub typedef int (*FsWalkCb)(char *entry, int is_dir, void *ud);
```

调用点：

```ct
import std::fs::Fs;
import std::fsguard::FsGuardOps;

char buf[65536];
int n = "src/main.c".read_chunk(0, buf, 65536);

char norm[256];
"src/../main.c".normalize_to(norm, 256);   // norm == "main.c"

"src".walk(on_entry, ud);

if ("src/a.c".is_under("/workspace/src")) { ... }
```

四个新方法名与 std::fs 的 4 个、std::str 的 14 个不冲突，同一文件可共存。

2.2 有状态策略 → 挂 FsGuard *

```ct
pub struct FsGuard {
    char *_root;
    char *_allow_prefix;
    char *_deny_pattern;
    int   _max_depth;
    FsError _last_error;
    int   _has_error;
} use Drop;

impl FsGuard {
    static FsGuard *new(char *root);          // root 为 NULL 则不做根约束
    FsGuard *allow_prefix(char *prefix);
    FsGuard *deny_pattern(char *glob);
    FsGuard *max_depth(int depth);            // 默认 16

    int check(char *path);                    // 0 允许，非 0 为 FS_ERR_*
    int read_file(char *path, char *buf, int cap);
    int write_file(char *path, char *data, int len);
    int read_chunk(char *path, long offset, char *buf, int len);
    int walk(char *root, FsWalkCb cb, void *ud);

    int      has_error();
    FsError *last_error();                    // 下次操作后失效
    void     clear_error();
}
```

FsGuard::read_chunk 与 char *::read_chunk 同名不冲突——不同宿主类型，CT 允许跨宿主同名。内部实现就是“先 check(path)，再调 path.read_chunk(...)”。

2.3 FsError

```ct
pub struct FsError {
    int   code;
    char *path;       // malloc，由 FsGuard 管理
    char *message;    // malloc，由 FsGuard 管理
};

#define FS_OK                   0
#define FS_ERR_NOT_FOUND        1
#define FS_ERR_PERMISSION       2
#define FS_ERR_OUT_OF_BOUNDS    3
#define FS_ERR_DENIED_PATTERN   4
#define FS_ERR_IS_DIR           5
#define FS_ERR_NOT_DIR          6
#define FS_ERR_BUFFER_TOO_SMALL 7
#define FS_ERR_IO               8
#define FS_ERR_OOM              9
```

last_error() 返回内部指针，下次任何 FsGuard 操作后失效。跨操作保留必须 strdup。

---

3 核心语义

3.1 check 判定顺序

```
输入 path
  ↓ 1. 规范化（消解 . 和 ..，统一分隔符，不越过根）
  ↓ 2. 若 _root != NULL：规范化后的路径必须以 _root 为前缀（路径段边界，非字符串前缀）
  ↓ 3. 若 _policy_enabled：
       a. _allow_prefix != NULL 且不在前缀下 → FS_ERR_OUT_OF_BOUNDS
       b. _deny_pattern != NULL 且匹配 → FS_ERR_DENIED_PATTERN
  ↓ 4. FS_OK
```

路径段边界：/workspace/src 是 /workspace/src/a.c 的前缀，但不是 /workspace/src2/a.c 的前缀。

3.2 read_chunk

· seek 到 offset，读最多 len 字节到 buf。
· 返回实际字节数；0 = EOF；-1 = 错误。
· 不自动补 NUL，二进制安全。
· 每次重新打开文件（MVP 不做句柄缓存）。

3.3 walk

· 深度优先，包含 root 本身（先回调 root，再递归子项）。
· 超过 _max_depth 不递归，但当前条目仍回调。
· 回调返回非 0 中断遍历。
· 每个子项回调前 check，越界子项跳过（不中断）。
· 遍历顺序不承诺（依赖 std::fs::list 顺序）。

3.4 normalize_to

· 只做词法规范化，不访问文件系统，不解析符号链接。
· .. 消解到根为止，不越过根（../etc 保持 ../etc）。
· MVP 只用 POSIX /；Win32 \ 在 P2 平台包做。

3.5 FsWalkCb 所有权契约

1. entry 生命周期到回调返回为止，是 borrow。
2. 跨回调保留必须显式 strdup。
3. 回调不得 free(entry)。
4. ud 归注册方所有。
5. walk 返回后，旧 entry 的裸指针可能悬垂。

---

4 对 CT 语言的依赖

需求 用途 状态
L11（函数指针） FsWalkCb 已支持
L5（own 只认 malloc） new() 返回裸指针，显式 delete 包层适配
L4（回调所有权契约） FsWalkCb 的 entry 是 borrow 契约文档
L8（错误传播） int 返回 + last_error() defer 等 P38，MVP 用返回码

不阻塞任何 CT 语言特性。 _xxx 私有逻辑用 .ct 内 static 自由函数，.h.ct 只暴露公开方法面。

---

5 跨平台

MVP 只做 POSIX。std::fs 本身是 C 宿主映射，接口跨平台一致；ct-fsguard 的路径规范化、沙箱检查、遍历都是词法操作，MVP 用 POSIX /。

P2 平台分层：

```
ct-fsguard          （契约包：策略、错误、遍历框架）
ct-fsguard-posix    （POSIX 路径规范化 + list 调用）
ct-fsguard-win32    （Win32 路径规范化 + 盘符 + 大小写折叠）
```

用 -I 选实现包，与 ct-process 的平台分层约定一致。

---

6 验收标准

正向夹具

编号 内容
F1 "src/../a.c".normalize_to(out, 256) 输出 "a.c"
F2 "big.log".read_chunk(0, buf, 100) 返回 100，内容正确
F3 "big.log".read_chunk(100, buf, 100) 返回 100，偏移正确
F4 "big.log".read_chunk(EOF, buf, 100) 返回 0
F5 "dir".walk(cb, ud) 遍历嵌套目录，回调计数正确
F6 "src/a.c".is_under("/workspace/src") 返回 1
F7 "src2/a.c".is_under("/workspace/src") 返回 0
F8 g->read_file 越界路径返回 -1，last_error 是 FS_ERR_OUT_OF_BOUNDS

负例

编号 输入 预期
N1 同一文件 import std::fs::Fs + import std::fsguard::FsGuardOps，调用 path.exists() + path.read_chunk(...) 编译通过，无歧义
N2 同一文件 import std::str::String + import std::fsguard::FsGuardOps 编译通过，无歧义
N3 "../etc/passwd".normalize_to(out, 256) 输出 "../etc/passwd"，is_under 返回 0
N4 path.read_chunk 在 offset 超文件大小 返回 0，不报错
N5 path.walk 回调返回非 0 walk 返回该值，中断遍历
N6 read_file 缓冲区不足 FS_ERR_BUFFER_TOO_SMALL，不截断
N7 last_error() 指针在下一次操作后 内容已变（指针失效）

N1 / N2 是关键验证——证明 char * 宿主方法可共存。

---

7 实施顺序

阶段 内容 依赖
G0 契约冻结：错误码、last_error 生命周期、check 判定顺序、walk 越界规则 —
G1 char * 上的 read_chunk / normalize_to / walk / is_under —
G2 FsError + FsGuard 骨架 + new / Drop / has_error / last_error L5
G3 FsGuard::check（根路径 + 前缀 + 黑名单 + 路径段边界） G1
G4 FsGuard::read_file / write_file / read_chunk / walk（check + 调原语） G3
G5 策略配置 + 错误信息自然语言化 + 负例补齐 G4

G1 优先——无状态原语是独立价值，不依赖 FsGuard。FsGuard 的策略方法只是“check + 调原语”。

---

8 风险

编号 风险 处置
R1 路径段边界写成字符串前缀，/src 匹配 /src2 按段拆分比较，或确保路径以 / 结尾再比较；F7 钉住
R2 .. 消解越过根，/tmp/test/../../etc 逃逸 消解时记录“已到根”，超出部分保留 ..；N3 钉住
R3 last_error 指针未失效，调用方读旧错误 每次操作开头 clear_error；N7 钉住
R4 walk 的 entry 回调返回后被释放，回调存了指针 契约五条写进 README；entry 用内部缓冲区，回调后复用
R5 std::fs::list 顺序不稳定 不承诺遍历顺序，夹具只断言集合相等
R6 符号链接指向沙箱外，MVP 不拦截 文档明确“MVP 不解析符号链接”，P2 加 follow_symlinks
R7 ct-fsguard 的 char * 方法与同文件已 import 的 trait 撞名 新方法名查 std 的 22 个名字表；四个新名字已确认不冲突；N1/N2 钉住
R8 同文件同时用 std::fs::readFile 和 ct-fsguard::read_chunk，语义混淆 文档明确：前者“一次性读入”，后者“按 offset 分块”；可共存不互斥

冻结面：std::fs API 不改；char * 宿主不新增 std 已有的 22 个名字；FsGuard 公开面在 G0 冻结；错误码整数在 G0 冻结，后续只追加。

---

9 需评审线确认

1. FsGuard * 上的方法与 char * 宿主方法是否零冲突？ 本提案假设不同宿主类型互不影响，请确认。
2. std::fs::list 返回顺序是否稳定？ 稳定则 walk 可承诺顺序；不稳定则夹具只断言集合相等。
3. std::fs::readFile 的 cap 语义：容量不足返回 -1，ct-fsguard::read_file 直接复用（不截断），请确认。
4. FsWalkCb 签名是否需加 long size？MVP 不加，P2 按需扩展。
5. Win32 平台包是否在本轮范围？MVP 只做 POSIX，Win32 在 P2。

---

10 一句话总结

ct-fsguard 是 std::fs 之上的策略感知层。 无状态原语（read_chunk / normalize_to / walk / is_under）直接挂 char *，符合 CT 风格，与 std::fs / std::str 零命名冲突；有状态策略（check / read_file / last_error）挂 FsGuard *，内部是“check + 调原语”。不阻塞任何 CT 语言特性，MVP 只做 POSIX。G1 优先——无状态原语是独立价值。
