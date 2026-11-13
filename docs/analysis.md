# ct-fsguard 提案评估

> 只读评估；未建仓库、未写实现、未改 ct-lang。事实来源：ct-lang HEAD、`/tmp/ctpkg-std`（`ct-pkg/std` clone）、本机 `cc` 探针。

## 1 一句话结论

**不能按原样立项。** 不是“补几个函数”的问题：`char *` 宿主的 trait 写法不合法、`#define` 常量与 `.m.ct` 文件形态对不上，
`last_error`/`walk`/`check` 的契约有多处空白，且“路径沙箱”在不处理符号链接时可以被直接绕过。先把 §7 的 1–10 在 G0 前改完；
11–12 可在 G0/G3/G4 收口，再谈 G1。

## 2 假设核验（8 行）

| # | 假设 | 结论 | 证据 | 不成立时怎么办 |
| --- | --- | --- | --- | --- |
| 1 | `pub trait FsGuardOps for char *` 合法 | **不成立**。`.m.ct` 的 `pub trait` 只写抽象方法，类型宿主由 `map trait T for type char * { … }` 绑定；没有 `pub trait X for char *` 这种形式 | `docs/language-spec.md:498-503`（`.m.ct` 白名单）、`:528-534`（类型宿主）；`test/ast/156_into_scalar/lib/lib.m.ct:20`（`map trait TextOps for type char *`） | 拆成 `FsGuardOps.m.ct`：`pub trait` + `map trait`；方法体放 `FsGuardOps.shim.h` 的 `static inline`。同一文件只 import 两个 `.m.ct` 后，`path.exists()` 与 `path.read_chunk()` 可共存；同名才歧义，需 `a::Trait::method(receiver, …)` 限定（`:535-539`） |
| 2 | 字符串字面量可直接调方法 | **成立**。字面量是 primary 接收者，0.20.0 起支持；不只一条调用，链式也允许 | `test/modules/map_unit_literals/main.ct:20-22`（`"lit".toString()`、`"abcd".len()`）；`docs/language-spec.md:528-534` | 若目标 CT 版本 < 0.20.0，先赋给 `char *` 变量；本仓 HEAD 不需要 |
| 3 | `#define FS_OK 0` 等 10 个常量 | **不成立（写法）**。CT 没有预处理器；`#define` 只在 `.m.ct` prologue/`#ct-raw` 透传，`.h.ct` 不能靠它定义 CT 常量 | `docs/language-spec.md:1592-1604`（无预处理器、全大写按宏放行）、`:498-500`（`.m.ct` 才允许 `#define`）、`:705-708`（`pub enum` 成员是跨单元常量） | 用 `pub enum FsErrCode { FS_OK = 0, FS_ERR_NOT_FOUND = 1, … }`；消费单元裸名/限定名都能用。不要用 `#define` 混进 `.h.ct` |
| 4 | `long` 类型存在 | **成立**。类型关键字表含 `long`，`long long`/`int64_t` 也有；声明原样发射 | `docs/language-spec.md:979-982`；`test/ast/51_cast_header_type/prog.ct:9` | POSIX LP64 上 `long` 是 64 位，但 Win32 LLP64 是 32 位；偏移量改用 `long long` 或 `int64_t`，不要用 `long` 做跨平台文件偏移 |
| 5 | `static FsGuard *new(char *root)` + `delete`；`use Drop` 与 `char*` 字段无额外限制 | **语言上成立，但 `use Drop` 不会自动释放 `char*` 字段**。显式 `impl Drop` 时编译器不生成字段 glue；不写 `impl Drop` 就只 `free(self)`，`_root`/`_allow_prefix`/`_deny_pattern`/`_last_error` 全泄漏 | `selfhost/ct-ast/backend/mem/Memory.h.ct:90-92`（`own` 只认 malloc/calloc）；`backend/emit/Emitter.h.ct:2881-2896`（显式 impl 跳过 glue）、`:3501-3518`（`delete` 只调 `T_Drop_drop` + `free(p)`） | 工厂返回值用 `delete`，不要 `own`；必须写 `impl Drop for FsGuard { void drop() { free 四个字段; } }`；`FsError.path/message` 也在 drop 里释放 |
| 6 | `std::fs` 的能力与提案 §1 表一致 | **成立**。`FsOps` 只有 `exists/readFile/writeFile/list`；`readFile` 容量不足返回 -1（含 NUL，不截断）；`list` 用 `\n` 连接、无尾换行、`readdir` 顺序、失败 -1、不返回部分；`exists` 是 `stat` | `/tmp/ctpkg-std/std/fs/Fs.m.ct:26-38`；`/tmp/ctpkg-std/std/fs/Fs.shim.h:41-74`、`:94-131`；`/tmp/ctpkg-std/std/fs/README.md` §4 | `readFile` 不能直接区分“文件不存在/太大/IO 错”；`FsGuard::read_file` 要自己 `stat`/`errno` 映射到 `FS_ERR_*`，不能只把 -1 转发 |
| 7 | `char *` 上已有 22 个方法名，四个新名字不冲突 | **成立**。4 个 fs + 14 个 str + 1 个 io `open` + 3 个 utf8 = 22；`read_chunk/normalize_to/walk/is_under` 均未占用 | `/tmp/ctpkg-std/std/fs/Fs.m.ct:26-38`；`/tmp/ctpkg-std/std/str/String.m.ct:49-64`；`/tmp/ctpkg-std/std/io/File.m.ct:11-17`；`/tmp/ctpkg-std/std/utf8/Utf8Ops.m.ct:41-45` | 第三方若也映射 `walk`，调用点会歧义；保留限定调用写法并在 README 说明。`std::fs` 与 `std::str` 的 4+14 是 18，R7 的 22 是加上 io/utf8 后的总数 |
| 8 | `strdup`/`free`/`snprintf` 包内可直接用 | **基本成立，但 `strdup` 有平台前提**。`free` 需 `<stdlib.h>`；`snprintf` 是 C99，`<stdio.h>`；`strdup` 是 POSIX，不是 C99。本机 macOS `cc -std=c99 -Wall -Wextra` 探针通过，但严格 C99 的 glibc 可能隐藏它 | `/tmp/probe_strdup.c` 探针 `cc_rc=0`；`docs/language-spec.md:1592-1600`（C 符号按普通函数放行） | 包内写 `static char *fsguard_strdup(const char *s)`（`malloc + memcpy + NUL`），不依赖 `strdup` 的 feature macro；或定义 `_POSIX_C_SOURCE 200809L`（需在 include 前，CT prologue 顺序要核） |

## 3 语义问题（对 / 错 / 自相矛盾）

| # | 议题 | 判定 | 修正 |
| --- | --- | --- | --- |
| 1 | `..` 消解 | **自相矛盾**。§3.4 说“消解到根为止，不越过根”，R2 说“超出部分保留 `..`”，N3 只测相对路径。绝对路径 `/tmp/test/../../etc` 两者都得 `/etc`，无法分辨；`/tmp/../../../etc` 才会分叉：钳到根得 `/etc`，保留得 `/../etc` | 定一条：**绝对路径在根处钳住**（`/../etc` → `/etc`）；**相对路径保留前导 `..`**（`../etc` 不变）。`normalize_to` 和 `is_under` 共用这条规则；补绝对路径负例 |
| 2 | `last_error()` 生命周期 | **措辞错**。返回的 `FsError *` 地址通常不变，变的是 `path`/`message` 指向的字符串；说“指针失效”会让测试只断言 `e != NULL`，假绿 | 契约改成“`FsError *` 及其 `path`/`message` 在下一次 `FsGuard` 操作后失效；要保留就 `strdup`”。N7 改为：存 `e1->path`/字符串，触发第二次错误，断言内容已变；读旧 `path` 用 ASan 验 UAF。`clear_error()` 后 `last_error()` 返回 NULL 还是 `FS_OK` 要定 |
| 3 | `check` 判定顺序与错误码 | **漏**。规范化后越出 `_root` 报什么码没写；`_root == NULL` + `_allow_prefix` 时谁生效也没写；`_policy_enabled` 在结构体里根本不存在 | `_root` 越界、`allow_prefix` 越界都报 `FS_ERR_OUT_OF_BOUNDS`；`deny` 报 `FS_ERR_DENIED_PATTERN`；`_root == NULL` 时只走 allow/deny；`_policy_enabled` 改为派生 `(_root != NULL \|\| _allow_prefix != NULL \|\| _deny_pattern != NULL)`，不要新增未初始化字段 |
| 4 | 相对路径 + 绝对 `_root` | **漏**。`check("src/a.c")` 与 `_root="/workspace"` 的前缀比较必然失败；提案没说先解析还是拒绝 | MVP 直接拒绝：`_root` 为绝对路径时，输入相对路径报 `FS_ERR_OUT_OF_BOUNDS`；或明确“相对路径按 `_root` 解析”。选一种并写进 G0 |
| 5 | `walk` 的 root / 深度 / 错误 | **漏**。只写“子项回调前 check”，root 是否 check 没写；root 越界行为没写；`max_depth=0` 是否只回调 root 没写；不可读子目录是跳过还是中断没写；`char *::walk` 根本没有深度参数 | 明确：root 先 check，越界返回 -1/不回调；depth 0 = root，`max_depth=0` 只回调 root；`max_depth<0` 拒绝；`list` 失败按 `FS_ERR_PERMISSION`/`IO` 中断或跳过（选一种）；`char *::walk` 增加 `max_depth` 或改为内部共享 walker |
| 6 | `deny_pattern` 的 glob 方言 | **漏**。`*` 是否跨 `/`、`**` 是否存在、大小写、匹配全路径还是 basename、目录是否匹配，全没定义 | G0 冻结最小方言：`*`/`?` 不跨 `/`，`**` 跨段（若需要），大小写敏感，按规范化全路径匹配，目录匹配则跳过整棵子树。用 `fnmatch(FNM_PATHNAME)` 或自写，测试钉住 |
| 7 | `is_under` 与 `_root` 判定重复 | **错（实现风险）**。两处都做“路径段边界”，提案没说共用；R1 只说“按段拆分比较” | 只留一个 `static int path_is_under(const char *path, const char *prefix)`（inclusive：相等返回 1），`check` 与 `is_under` 都调它；`/workspace/src` 与 `/workspace/src2` 的边界只测一次 |
| 8 | 符号链接逃逸 | **重大语义错**。`check` 只做词法规范化；`read_file`/`read_chunk` 用 `fopen`、`walk` 用 `opendir` 都会跟随符号链接。`/workspace/src/evil -> /etc` 通过 `check` 后能读 `/etc/passwd`，`R6` 的“MVP 不拦截”等于承认它不是沙箱 | 立项前二选一：A）安全边界——逐段 `openat(O_NOFOLLOW)` / `lstat` 拒绝符号链接，或 `realpath` 后重新做段比较；B）明确降级为“词法策略层，不是安全边界”，改名/文档写死，不宣称 sandbox。若选 A，`std::fs` 的 `readFile/list` 不能直接用，需包内 POSIX 原语 |
| 9 | `read_file` 容量边界 | **漏**。`std::fs::readFile` 的 `cap` 含 NUL；文件 `cap-1` 字节成功，`cap` 字节失败。提案只写 `FS_ERR_BUFFER_TOO_SMALL`，没给“恰好等于 cap”的判据 | `cap` 含 NUL；文件大小 `<= cap-1` 成功，`== cap` 失败；失败时缓冲区不写半截。补 F/N 各一条 |
| 10 | `read_chunk` 边界 | **漏**。负 offset、offset 恰好 EOF、`len<=0`、目录/FIFO、文件大于 2GB 都没写；`long` 在 32 位平台会截断 | 负 offset 返回 -1（`FS_ERR_IO` 或新增 `FS_ERR_INVALID`）；offset==EOF 返回 0；`len<=0` 返回 0/-1 明确；非普通文件用 `fstat` 拒绝 `FS_ERR_IS_DIR`；偏移用 `long long`/`int64_t` |
| 11 | 错误码映射 | **漏**。`char *` 原语只返回 -1，`FsGuard::read_file` 无法知道是 NOT_FOUND、PERMISSION、IS_DIR 还是 IO；提案的 `FS_ERR_*` 分类没有来源 | 包内统一 `fsguard_errno_to_code(int e)`；`stat` 先判存在/类型，`open`/`read` 失败再按 `errno` 映射；`FS_ERR_OOM` 只在 `malloc/strdup` 失败时用 |
| 12 | `FsError` / `FsGuard` 的所有权 | **漏**。`path`/`message` 是 malloc，谁 free、`last_error` 返回后调用方能否改、`clear_error` 是否置空、`FsGuard::drop` 是否释放，都没写 | `FsGuard` 独占 `_last_error.path/message`；`clear_error` 释放并置 NULL；`last_error` 返回只读借用；`drop` 释放所有 `char*`；`FsError` 本身不单独 `use Drop`，避免双重释放 |
| 13 | `normalize_to` 容量/重叠 | **漏**。`out` 太小、`out == path`、空串、`/`、尾斜杠、重复 `/` 都没定义 | `cap` 含 NUL；结果长度 `>= cap` 返回 -1 且 `out[0]=0`（不写半截）；`out` 与输入重叠时先用临时缓冲或文档禁止；空串→`.`（或 -1，选一），`/`→`/` |
| 14 | `walk` 的 `entry` 借用 | **对（已写契约），但测试不够**。R4 说内部缓冲复用；回调存指针后下一次回调就变 | 契约五条保留；测试：回调里存 `entry`，下一个回调断言旧指针内容已变；ASan 验 walk 返回后读取。若希望安全，提供 `fsguard_strdup(entry)` 示例，不新增 API |
| 15 | `FsGuard::walk` 是否复用 `char *::walk` | **错（实现缺口）**。`char *::walk` 无 policy/深度；`FsGuard::walk` 只“check root + 调原语”无法做到“每个子项 check” | 抽共享 walker：`walk_impl(root, max_depth, predicate, cb, ud)`；`char *` 版传 `predicate=NULL`，`FsGuard` 版传 `check`。两处都不要各写一遍递归 |

## 4 验收用例审查

| 用例 | 判定 | 修改/补充 |
| --- | --- | --- |
| F1 `"src/../a.c"` → `"a.c"` | 可留 | 加绝对路径 `/tmp/test/../../etc`、`/`、尾斜杠、重复 `/`、`out` 容量不足 |
| F2/F3 `read_chunk` 0/100 | 可留，但依赖夹具 | 测试启动时生成固定 300 字节文件（内容 `0..299`），放 `test/fixtures/fsguard/` 或运行时生成；不要依赖仓库里的大文件 |
| F4 EOF 返回 0 | 可留 | 加 offset==EOF、offset>EOF、`len=0`、负 offset |
| F5 `walk` 回调计数 | **要改**。只断计数，条目错/重复也能绿；与 R5“顺序不稳定”不冲突，但不能只数数 | 回调收集 `(path,is_dir)`，排序后与期望集合比较；断言 root 包含、深度限制、deny 目录整棵跳过、不可读子目录行为 |
| F6/F7 `is_under` | 可留 | 加 path==prefix（应为 1）、prefix 尾斜杠、`/src2` 边界、`../etc` 为 0 |
| F8 越界 `read_file` | 可留 | 断言 `code == FS_ERR_OUT_OF_BOUNDS`、`path` 是规范化后的路径、`message` 非空；再加 root 本身允许 |
| N1 同文件 `std::fs::Fs` + `FsGuardOps` | **按原样编译不过**（假设 1）；改成 `map trait` 后可留 | 编译 + 运行；`path.exists()` 与 `path.read_chunk()` 都调用；再加一个同名冲突的假映射，证明歧义与限定调用 |
| N2 `std::str::String` + `FsGuardOps` | 同上 | 编译 + 运行；`path.len()` + `path.read_chunk()` 共存；确认 14+4 个名字无冲突 |
| N3 `../etc/passwd` 原样 | 可留但只覆盖相对路径 | 加 `/../etc/passwd`、`/tmp/../../../etc`，按 §3.1 的“绝对钳根/相对保留”断言；`is_under` 为 0 |
| N4 offset 超文件大小 | 可留 | 加负 offset、offset==EOF、目录路径 |
| N5 回调非 0 中断 | 可留 | 断言 walk 返回**原值**、后续回调次数为 0；root 回调返回非 0 也要中断 |
| N6 缓冲区不足 | 可留 | 加“恰好 `cap-1` 字节成功 / 恰好 `cap` 字节失败”；失败时缓冲区不被写半截；`read_file` 与 `read_chunk` 分开测 |
| N7 `last_error()` 指针失效 | **要改，否则假绿**。只断言 `e != NULL` 或指针地址不变，什么都没证明 | 存 `e1->path`/字符串副本；触发第二次错误；断言 `e1->path` 内容已变/被释放（ASan）；再测 `clear_error()` 后 `last_error()==NULL`；不要只比 `e1` 地址 |
| 缺失负例 | — | 规范化路径 == `_root`（**应为允许**，不是负例）；`read_file` 恰好 cap；`walk` 不可读子目录；`deny_pattern` 匹配目录；offset 负；`normalize_to` cap 不足；`is_under` 相等/尾斜杠；`walk` root 越界；`new(NULL)`；`drop` 后 ASan/泄漏；二进制含 NUL 的 `read_chunk`/`write_file` |

## 5 与既有条款的关系

| 条款 | 关系 |
| --- | --- |
| `bindings-and-patterns.md` §3 函数指针 | `FsWalkCb` 是 `pub typedef` 函数指针，L11 已支持；跨模块用 `.h.ct` 的 `pub typedef`。消费者只能传具名函数/函数指针；CT 闭包不是普通函数指针（SH-67），文档要给 `static int cb(char *, int, void *)` 例子 |
| 同上 §5 `own` | `new()` 是工厂返回，不能 `own`；用 `delete`。`own` 只认裸 `malloc/calloc`；给返回值加 cast 反而破坏识别（`Memory.h.ct:119-127`） |
| 同上 §2 `.m.ct` 变参 | 本包不定义变参函数；`snprintf` 是 C 变参**调用**，不是 `.m.ct` 变参尾，不受 L6 的 `curl_setopt_*` 约束 |
| 同上 §6 可空取值 | `last_error()` 返回 NULL/零值、`read_file` 返回 -1 的判空写法要统一；不要解引用 -1 结果 |
| `phase40-draft.md` L1 自定义 `[]` | **无依赖**。`path[0]` 是 C 的 `char*` 下标，不是自定义 `get/set`；L1 只对用户 struct 生效。若将来给 `FsGuard` 加 `get/set`，才相关 |
| L1–L12 | 依赖 L11（函数指针）、L5（工厂+delete，无改动）、L4（借用契约，文档）；不依赖 L8 的 `errdefer`（MVP 返回码）；不用 L7 的语言内 `#ifdef`（POSIX/Win32 用包分层，和提案 §5 一致）；不用 L10（`char*::read_chunk` 与 `FsGuard::read_chunk` 是不同宿主，不是重载）；L1/L2/L3/L6/L9/L12 未使用。与 L1/L2/L8 无冲突 |
| Phase 38 `defer` | 可选：`FsGuard::read_file` 里打开/关闭用 `defer` 能减样板，但不是硬依赖；MVP 用显式 `fclose` 即可 |

**语言能力：不需要新增。** 唯一像语言需求的几件事都能用现有机制降级：`pub trait X for char *` → `map trait` 已有；
`use Drop` 自动释放 `char*` → 显式 `impl Drop`；工厂返回值 `own` → `delete`；回调借用检查 → 契约 + ASan 测试；
`#define` 常量 → `pub enum`；固定宽度偏移 → `long long`/`int64_t`。没有需要动编译器、判据或门禁的条目。

## 6 阶段切分意见（只给意见，不出卡）

- **G0 拆成 G0a/G0b**：G0a 冻结 API 形态（`.m.ct` + `map trait`、`FsWalkCb` 放 `.h.ct`、`pub enum` 错误码、shim 命名）；G0b 冻结语义（绝对/相对 `..`、root 与相对路径、错误码映射、`last_error` 生命周期、glob 方言、walk root/深度/不可读/符号链接、cap 边界）。现在 G0 一页装不下。
- **G1 保留“无状态原语优先”**：`read_chunk`/`normalize_to`/`is_under` 先做；`walk` 若也放 G1，必须一开始就是共享 walker（带 `max_depth`/predicate），否则 G4 会复制递归。
- **G2 与 G1 可并行**：`FsError`/`FsGuard` 骨架/`new`/`drop` 不依赖原语实现；但 `FsGuard::read_chunk` 要等 G1。
- **G3 合并 G5 的策略配置**：`allow_prefix`/`deny_pattern`/`max_depth` 的 setter 就是 check 的一部分，不要留到 G5 才做；G3 同时落共享 `path_is_under`。
- **G4 只做“check + 原语 + errno 映射”**；`FsGuard::walk` 必须走共享 walker，不能只 check root 再调 `char *::walk`。
- **G5 不应是独立实现阶段**：错误信息自然语言化、README/负例补齐跟随 G3/G4；G5 只留文档、示例与跨平台骨架。把“负例补齐”放 G5 会重演 F5/N7 的假绿。
- **建议顺序**：G0a → G0b → G1（原语 + 夹具）∥ G2（错误/骨架）→ G3（check + policy）→ G4（包装 + 遍历）→ G5（文档/示例）。G1 的原语可先给 `FsGuard` 之外的项目用，符合“独立价值”。

## 7 必须先改的条目清单

1. **把 `pub trait FsGuardOps for char *` 改成 `pub trait` + `map trait … for type char *`**，方法体放 `.shim.h`；否则整份 API 不是合法 CT。
2. **`FsWalkCb` 从 `pub typedef` 移到 `.h.ct`（或 `.m.ct` 的 `pub type`）**；`.m.ct` 不产出头，消费者看不到。
3. **10 个 `#define` 改成 `pub enum FsErrCode`**；CT 没有预处理器，`.h.ct` 不能靠宏定义 CT 常量。
4. **补 `_policy_enabled` 的定义**（派生自三个策略指针），并冻结 `check` 的错误码：root/allow 越界 → `OUT_OF_BOUNDS`，deny → `DENIED_PATTERN`。
5. **冻结绝对/相对 `..` 规则**：绝对钳根、相对保留前导 `..`；`normalize_to` 与 `is_under` 共用。
6. **决定符号链接策略**：要么 `lstat`/`openat(O_NOFOLLOW)`/`realpath` 做真沙箱，要么明确降级为“词法策略层，不是安全边界”；不能既叫沙箱又不处理链接。
7. **补 `FsGuard` 的显式 `impl Drop`**：释放 `_root`/`_allow_prefix`/`_deny_pattern`/`_last_error.path/message`；`use Drop` 本身不释放 `char*`。
8. **定 `last_error` 契约**：返回只读借用，`path`/`message` 下次操作后失效；`clear_error` 释放并置 NULL；N7 改内容/ASan 断言。
9. **定 `walk` 契约**：root 先 check、`max_depth=0` 只回调 root、不可读子目录/deny 目录/符号链接的处理、回调非 0 原值返回；`char *::walk` 补 `max_depth` 或共享 walker。
10. **定 `deny_pattern` 的 glob 方言**（`*` 不跨 `/`、`**`、大小写、全路径 vs basename、目录匹配）；否则 R7 和验收用例无法写。
11. **定容量与偏移边界**：`read_file` 的 cap 含 NUL（`cap-1` 成功/`cap` 失败）、`read_chunk` 负 offset/EOF/`len<=0`、`normalize_to` 的 cap；偏移改用 `long long`/`int64_t`。
12. **补错误映射与 `strdup` 降级**：`errno → FS_ERR_*` 的表；`strdup` 换成包内 `fsguard_strdup`（或明确 POSIX feature macro），避免严格 C99/Linux 下不可用。
