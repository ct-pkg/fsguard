# ct-fsguard 需求分析

> 状态：**需求层梳理完成，未立项**。本文只把提案拆成可判定的需求，不做设计、不出 phase 卡、不排 roadmap、不写实现。
> 依据：`docs/proposal.md`（提案原文，未改动）、`docs/analysis.md`（评估）、`docs/design.md`（12 条待决项）、`README.md`。
> 口径优先级：**README 边界声明 > 评估修正 > 提案原文**。本文的改后口径与提案原文冲突时，以本文为准，但 `proposal.md` 原文保持不动。

## 1 摘要

| 项 | 数量 |
| --- | --- |
| 需求条目 | 17（R-01 … R-17） |
| 待确认项 | 7（Q-1 … Q-7） |
| 评估判定"必须先改"的条目 | 12（C-01 … C-12），其中 3 处硬伤（H-1 … H-3） |
| 本次新发现的需求缺口（评估未覆盖） | 5（G-1 … G-5） |
| 对 CT 语言能力的硬阻塞 | 0 条（按改后口径）；原文写法造成 2 处硬阻塞，见 H-1/H-2 |
| 对 CT 语言能力的软阻塞 | 0 条；另有 2 处**非语言**的设计缺口（R-07 的 `walk` 签名、R-13 的共享 walker） |

**判据形态约定**（全文适用）：

1. 每条需求至少有一条**运行断言**（退出码 / 返回值 / 字节比较 / 输出文本）或**可核对产物**（grep 计数、字段清单、文件存在性、行号）。
2. **"能编译通过"不单独构成判据**；涉及 API 形态的需求，编译只是前置条件，必须在运行时断言行为。
3. 夹具一律运行时生成（不依赖仓库内大文件），路径按 POSIX `/` 处理。
4. 负数用例必须断言**具体错误码与错误内容**，不得只断言返回 `-1` 或非 0。

## 2 需求条目

### 2.1 包形态与兼容

#### R-01 包形态：`pub trait` + `map trait … for type char *`

- **要解决**：提案 §2.1 的 `pub trait FsGuardOps for char *` 不是合法 CT 写法（评估 §2.1）；需要先冻结包的可编译形态与文件分工，否则整份 API 不成立。
- **改后口径**：`FsGuardOps.m.ct` 内写抽象 `pub trait FsGuardOps { … }`，再用 `map trait FsGuardOps for type char *;` 绑定宿主；方法体放 `FsGuardOps.shim.h` 的 `static inline`；公开结构体与函数指针类型放 `.h.ct`；私有逻辑用 `.ct` 内 `static` 自由函数。
- **验收判据**：
  1. 包内不存在 `pub trait … for char *` 形式（grep 命中数 = 0）。
  2. 消费者单元只 import 本包的 `.m.ct`，对 `char *` 调用四个方法，并 assert 返回值（运行）。
  3. `FsWalkCb` 可从 `.h.ct` 被消费者看见：消费者声明具名回调并作为参数传入，`walk` 实际调用到该函数（运行，断言调用次数）。
  4. `.m.ct` / `.h.ct` 中 `#define` 出现次数 = 0（prologue / `#ct-raw` 透传块除外）。
- **非目标**：不改 ct-lang 编译器与语言规范；不引入新的宿主绑定语法；不新增关键字。
- **语言依赖**：**已支持**（`.m.ct` 白名单与 `map trait`，见评估 §2.1）。
- **设计缺口**：无（原文写法是硬阻塞，改后消除）。
- **来源**：proposal §2.1；analysis §2.1、§7.1、§7.2；design #1、#2。

#### R-02 错误码常量用 `pub enum`

- **要解决**：CT 没有预处理器，10 个 `#define FS_*` 不能在 `.h.ct` 里定义 CT 常量（评估 §2.3）。
- **改后口径**：`pub enum FsErrCode { FS_OK = 0, FS_ERR_NOT_FOUND = 1, FS_ERR_PERMISSION = 2, FS_ERR_OUT_OF_BOUNDS = 3, FS_ERR_DENIED_PATTERN = 4, FS_ERR_IS_DIR = 5, FS_ERR_NOT_DIR = 6, FS_ERR_BUFFER_TOO_SMALL = 7, FS_ERR_IO = 8, FS_ERR_OOM = 9 }`；名字与数值冻结，后续只追加（追加需 Q-5 裁定）。
- **验收判据**：
  1. `pub enum FsErrCode` 恰有 10 个成员，名字与数值同提案 §2.3 逐一对齐（可核对）。
  2. 消费单元分别用裸名 `FS_ERR_OUT_OF_BOUNDS` 与限定名 `FsErrCode::FS_ERR_OUT_OF_BOUNDS` 取值并 assert（运行）。
  3. 全包不存在以 `#define` 定义上述 10 个常量的位置（grep 命中数 = 0）。
- **非目标**：不用宏；不做错误码字符串化的稳定 ABI；不做 i18n。
- **语言依赖**：**已支持**（`pub enum` 成员可作跨单元常量，见评估 §2.3）。
- **设计缺口**：是否允许第 11 个码 → Q-5。
- **来源**：analysis §2.3、§7.3；design #3。

#### R-03 与 `std::fs` / `std::str` 的方法名共存

- **要解决**：`char *` 上已被 std 占用 22 个方法名（4 fs + 14 str + 1 io + 3 utf8），新增四名必须不撞名，且同文件混用无歧义（评估 §2.7）。
- **验收判据**：
  1. 同文件 import `std::fs::Fs` + 本包，对同一 `char *` 调用 `exists()` 与 `read_chunk(...)`，两者返回值各自 assert（运行，不只看编译）。
  2. 同文件 import `std::str::String` + 本包，调用 `len()` 与 `read_chunk(...)` 并 assert（运行）。
  3. 负例：另建一个测试用 `map trait` 也映射 `walk`，未限定调用必须编译失败（歧义），`Trait::walk(p, …)` 限定调用必须编译并运行成功。
  4. 本包新增方法名集合与 std 22 个名字的交集为空（可核对名单）。
- **非目标**：不占用、不改名、不重载 std 方法；不引入方法重载机制。
- **语言依赖**：**已支持**（同一宿主多 trait 共存；同名歧义用限定调用，见评估 §2.1）。
- **设计缺口**：无。
- **来源**：proposal §2.1、N1、N2；analysis §2.7。

### 2.2 无状态原语（挂 `char *`）

#### R-04 `read_chunk`：按 offset 分块读

- **要解决**：`std::fs` 只有一次性 `readFile`，大文件无法受控读取（提案 §1）。
- **验收判据**（运行时生成 300 字节夹具，内容为 0..299）：
  1. `read_chunk(0, buf, 100)` 返回 100，且 `memcmp` 与 0..99 相等。
  2. `read_chunk(100, buf, 100)` 返回 100，且与 100..199 相等。
  3. `read_chunk(300, …)` 返回 0；`offset > 300` 返回 0（EOF 不报错）。
  4. 负 offset 返回 -1，且 `FsGuard` 层 `last_error().code` 等于冻结值（见 R-14、Q-5）。
  5. 含内嵌 NUL 的二进制夹具逐字节相等（不截断、不自动补 NUL）。
  6. 公开签名偏移量为 `long long` / `int64_t`，公开面不出现 `long`（可核对签名）。
- **非目标**：句柄缓存；mmap；异步 I/O；并发读；`read_chunk` 之外的 seek/tell API。
- **语言依赖**：**已支持**（`long long` / `int64_t` 存在，见评估 §2.4）。
- **设计缺口**：负 offset 与 `len<=0` 的返回码需与 Q-5 一致。
- **来源**：proposal §3.2、F2–F4、N4；analysis §3.10、§7.11。

#### R-05 `normalize_to`：纯词法规范化

- **要解决**：`std::fs` 无路径规范化，沙箱比较没有共同基准（提案 §1）。
- **验收判据**（逐条运行，输入 → 输出）：

  | 输入 | 输出 |
  | --- | --- |
  | `src/../a.c` | `a.c` |
  | `./a` | `a` |
  | `a//b` | `a/b` |
  | `a/b/` | `a/b` |
  | `/` | `/` |
  | `../etc` | `../etc` |
  | `/../etc` | `/etc` |
  | `/tmp/../../../etc` | `/etc` |
  | `""`（空串） | `.` |

  1. 上表逐行 assert；`out` 容量不足时返回 -1 且 `out[0] == 0`（不写半截），`cap == len+1` 时成功。
  2. 对不存在的路径仍返回规范化结果（证明不访问文件系统）。
  3. 词法不跟随链接：准备 `link -> /etc`，输入 `link/passwd` 输出仍为 `link/passwd`。
  4. `out` 与输入重叠（`out == path`）被文档禁止，README 写明该限制（可核对）；实现不负责检测。
- **非目标**：不 `stat`、不 `realpath`、不解析符号链接；不做 Win32 `\`、盘符、大小写折叠；不做 URL 解码。
- **语言依赖**：**已支持**。
- **设计缺口**：`..` 规则需 Q-3 确认（上表按评估建议口径写）。
- **来源**：proposal §3.4、F1、N3；analysis §3.1、§3.13、§7.5。

#### R-06 `is_under`：路径段边界判定

- **要解决**：字符串前缀会把 `/workspace/src2` 误判为 `/workspace/src` 之下（提案 R1）。
- **验收判据**：
  1. `src/a.c` vs `/workspace/src` → 1；`src2/a.c` vs `/workspace/src` → 0。
  2. 相等（`/workspace/src` vs `/workspace/src`）→ 1。
  3. prefix 带尾斜杠（`/workspace/src/`）与不带结果一致。
  4. `../etc` vs `/workspace` → 0。
  5. 与 `check` 共用同一段边界函数（可核对：全包只有一处"按段比较"实现）。
- **非目标**：不做大小写不敏感比较；不做 inode/真实路径比较；不访问文件系统。
- **语言依赖**：**已支持**。
- **设计缺口**：无（输出依赖 Q-3 的规范化规则）。
- **来源**：proposal §3.1、F6、F7；analysis §3.7。

#### R-07 `walk`（无状态）+ 回调借用契约

- **要解决**：`std::fs::list` 只列一层；同时提案 F5 只数回调次数，条目错/重复也能绿（评估 §4）；且 `char *::walk` 没有深度参数，无法表达深度限制（评估 §3.5）。
- **改后口径**：签名改为 `walk(FsWalkCb cb, void *ud, int max_depth)`（与提案 §2.1 的三参数调用示例不兼容，见 Q-4），内部走共享 walker（R-13 复用）。
- **验收判据**：
  1. 固定夹具树（root + 3 子目录 + 5 文件、含 2 层嵌套）：回调收集 `(path, is_dir)`，排序后与期望集合逐项相等（不承诺顺序，不只比计数）。
  2. root 自身被回调一次且 `is_dir == 1`。
  3. `max_depth = 0` 只回调 root；`max_depth = 1` 回调 root + 直接子项。
  4. 回调返回 7 → `walk` 返回 7，其后回调次数为 0；root 回调返回非 0 也立即中断并返回原值。
  5. 20 层深树在 `max_depth = 16` 下不越界、不栈溢出（运行 + ASan）。
  6. 借用契约：回调内保存 `entry` 指针，下一次回调断言其内容已变（运行）；README 含五条契约（可核对）。
- **非目标**：不承诺遍历顺序；不跟随符号链接；不做并行遍历；不提供排序回调。
- **语言依赖**：**已支持**（函数指针 L11；回调为具名函数/函数指针，闭包不可用）。
- **设计缺口**：**有（非语言）**：`char *::walk` 必须补 `max_depth` 或改为共享 walker，否则判据 3 无法表达 → Q-4。
- **来源**：proposal §3.3、§3.5、F5、N5；analysis §3.5、§3.14、§7.9。

### 2.3 有状态策略（`FsGuard *`）

#### R-08 `FsGuard` 生命周期与所有权

- **要解决**：`use Drop` 不会释放 `char *` 字段；显式 `impl Drop` 时编译器跳过字段 glue，不写就泄漏四个字段（评估 §2.5）。
- **验收判据**：
  1. `new("/ws/../ws")` 与 `new("/ws")` 行为一致（root 规范化后再存储）。
  2. `new(NULL)` 无根约束：未配置 allow/deny 时 `check("/etc/passwd")` 返回 `FS_OK`（运行）。
  3. 显式 `impl Drop for FsGuard` 释放 `_root`、`_allow_prefix`、`_deny_pattern`、`_last_error.path`、`_last_error.message`（可核对）+ 构造/配置/delete 全链路 LSan 零泄漏（运行）。
  4. 工厂返回值用 `delete` 释放；公开示例不出现以 `own` 接收工厂返回值（grep 命中数 = 0）。
  5. 配置 setter 成功时返回同一 `FsGuard *`（可链式）；非法参数（如 `max_depth < 0`）返回 NULL，且原对象状态不变（运行 assert 原对象行为不变）。
- **非目标**：不做引用计数；不做线程安全；不做对象池；不提供拷贝构造/赋值。
- **语言依赖**：**已支持**（L5：`own` 只认裸 `malloc/calloc`；显式 `impl Drop` 跳过字段 glue）。
- **设计缺口**：setter 非法参数（如 `max_depth < 0`）的错误码 → Q-5。
- **来源**：proposal §2.2、§4；analysis §2.5、§5、§7.7；design #7。

#### R-09 `check`：判定顺序与错误码

- **要解决**：提案 §3.1 的 `_policy_enabled` 在结构体里不存在；root 越界报什么码、root 为 NULL 时谁生效、相对路径与绝对 root 如何相遇，都没写（评估 §3.3、§3.4）。
- **改后口径**：顺序冻结为 ① 规范化 → ② `_root` 段边界（越界 `FS_ERR_OUT_OF_BOUNDS`）→ ③ `_allow_prefix`（越界 `FS_ERR_OUT_OF_BOUNDS`）→ ④ `_deny_pattern`（命中 `FS_ERR_DENIED_PATTERN`）→ ⑤ `FS_OK`；`_policy_enabled` 改为派生式 `(_root != NULL || _allow_prefix != NULL || _deny_pattern != NULL)`，不新增字段。
- **验收判据**：
  1. `check("/ws/../ws/a")` 与 `check("/ws/a")` 结果相同（先规范化后比较）。
  2. `/workspace/src` 允许 `/workspace/src/a.c` 与自身，拒绝 `/workspace/src2/a.c`（`OUT_OF_BOUNDS`）。
  3. 不在 allow 下 → `OUT_OF_BOUNDS`；命中 deny → `DENIED_PATTERN`；两者同时成立时返回 `OUT_OF_BOUNDS`（顺序冻结，运行两个用例）。
  4. `check` 是纯词法、不访问文件系统：对不存在的路径返回 `FS_OK`；`FS_ERR_NOT_FOUND` 只能由读/写/遍历产生（运行）。
  5. `_root == NULL` 时只走 allow/deny（运行）；结构体字段清单中无 `_policy_enabled`（可核对）。
  6. 失败时 `last_error().path` 是规范化后的路径、`message` 非空（运行）。
  7. 绝对 `_root` + 相对输入按 Q-6 冻结值断言（当前建议：拒绝，`OUT_OF_BOUNDS`）。
- **非目标**：不做真沙箱（不 `lstat`、不 `realpath`、不 `openat`）；不访问文件系统；不做权限位检查。
- **语言依赖**：**已支持**。
- **设计缺口**：Q-3（`..`）、Q-5（错误码）、Q-6（相对路径）。
- **来源**：proposal §3.1、F8；analysis §3.3、§3.4、§7.4；design #4。

#### R-10 策略配置：`allow_prefix` / `deny_pattern` / `max_depth`

- **要解决**：三个 setter 的语义（覆盖还是叠加、默认值、空值）以及 glob 方言全未定义（评估 §3.6、§7.10）。
- **验收判据**：
  1. 默认 `max_depth = 16`：17 层树在 16 层停止（运行，与 R-07 判据 5 同夹具）。
  2. 同一 setter 连续调用两次只保留最后一次（覆盖语义，运行）。
  3. deny 最小方言（按 Q-7 建议）：`*` / `?` 不跨 `/`；大小写敏感；按规范化全路径匹配；命中目录则跳过整棵子树。用例：`/ws/secret/*.key` 匹配 `/ws/secret/a.key`，不匹配 `/ws/secret/deep/a.key`。
  4. allow 内命中 deny → `DENIED_PATTERN`（与 R-09 判据 3 互补）。
  5. 空串等价于"未配置"（运行）。
- **非目标**：MVP 不支持 `**`；不支持正则；不支持 basename 匹配；不支持多 pattern 列表。
- **语言依赖**：**已支持**（可用 libc `fnmatch` + `FNM_PATHNAME`，或包内自写）。
- **设计缺口**：glob 方言需 Q-7 确认。
- **来源**：proposal §2.2、§3.1、R7；analysis §3.6、§7.10；design #10。

#### R-11 `FsError` / `last_error` / `clear_error` 契约

- **要解决**："下次操作后失效"没说是结构指针失效还是 `path`/`message` 内容失效，N7 只比指针必然假绿（评估 §3.2、§4）；`clear_error` 后返回什么、谁 free 也未定（评估 §3.12）。
- **改后口径**：`last_error()` 返回**只读借用**；`FsError *` 及其 `path`/`message` 在下一次 `FsGuard` 操作后失效；每次公开操作开始清空错误；`clear_error()` 释放并置 NULL，此后 `last_error() == NULL`；`FsError` 不单独 `use Drop`，由 `FsGuard` 独占释放。
- **验收判据**：
  1. 每次公开操作开始清错；成功操作后 `has_error() == 0` 且 `last_error() == NULL`（运行）。
  2. 失败后 `last_error()` 非 NULL，`code` 与返回的 `FS_ERR_*` 一致，`path` 为规范化路径，`message` 非空（运行）。
  3. 保存第一次失败的 `e1->path` 字符串副本，触发第二次错误，断言旧指针内容已变（ASan 下无 UAF 读取）（运行）。
  4. `clear_error()` 后 `last_error() == NULL` 且 `has_error() == 0`（运行）。
  5. `check` 失败也置 `last_error`（运行，与 R-09 判据 6 同用例）。
  6. `FsError` 无独立 drop glue；`FsGuard::drop` 释放其 `path`/`message`（可核对 + LSan）。
- **非目标**：不做错误链 / backtrace；不暴露可长期持有的错误对象；不做错误码→字符串稳定 ABI。
- **语言依赖**：**已支持**。
- **设计缺口**：无（措辞已定）。
- **来源**：proposal §2.3、N7、R3；analysis §3.2、§3.12、§7.8；design #8。

#### R-12 `FsGuard` 读写包装：`read_file` / `write_file` / `read_chunk`

- **要解决**：`std::fs::readFile` 只返回 -1，无法区分 NOT_FOUND / PERMISSION / IS_DIR / IO；`write_file` 的失败语义在评估中完全未覆盖（见 G-1）。
- **验收判据**：
  1. `read_file`：`cap` 含 NUL；文件 `cap-1` 字节成功，`cap` 字节失败并返回 `FS_ERR_BUFFER_TOO_SMALL`（两个边界各一条运行用例）。
  2. 失败不写半截：缓冲区预填 `0xAA`，失败后仍全为 `0xAA`（运行）。
  3. `write_file`：写 `len` 字节（含内嵌 NUL）后落盘字节完全相等（运行，二进制夹具）。
  4. 越界路径：`write_file` 返回 -1、`code == FS_ERR_OUT_OF_BOUNDS`，且目标文件不存在（可核对 + 运行）。
  5. 错误映射：不存在 → `NOT_FOUND`；目录 → `IS_DIR`；无权限（chmod 000）→ `PERMISSION`；其余 → `IO`（运行）。
  6. 越界时先 `check` 后调原语：用一个越界且不存在的路径，返回 `OUT_OF_BOUNDS` 而非 `NOT_FOUND`（运行，证明未落到 I/O）。
  7. 不以 `std::fs::readFile` 的 -1 作为唯一错误来源：包内使用 `stat` / `open` / `errno` 映射（可核对）。
- **非目标**：不做原子写（临时文件 + rename）；不做 `fsync`；不做部分写重试；不做文件锁。
- **语言依赖**：**已支持**（Phase 38 `defer` 可选，非硬依赖）。
- **设计缺口**：`write_file` 失败时是否保留半截文件 / 是否截断 → Q-2。
- **来源**：proposal §2.2、§3.2、N6；analysis §3.9、§3.11、§7.11。

#### R-13 `FsGuard::walk`：每个子项过策略

- **要解决**：`FsGuard::walk` 若只 "check root + 调原语"，无法做到"每个子项 check"（评估 §3.15）；提案的"越界子项跳过"与不可读目录行为也未区分（评估 §3.5）。
- **验收判据**：
  1. deny 目录：其整棵子树 0 次回调，其余条目齐全，遍历不中断（运行）。
  2. root 先 check；root 越界返回 -1 且回调次数为 0（运行）。
  3. 与 R-07 共用同一 walker：全包只有一份目录递归实现（可核对）。
  4. 不可读子目录（chmod 000）按 fail-closed 处理：中断并返回 -1 + `FS_ERR_PERMISSION`（运行）。
  5. 同一夹具下 `char *::walk` 与 `FsGuard::walk` 的条目集合除被策略排除者外完全一致（运行）。
- **非目标**：不做并行遍历；不承诺顺序；不自动跟随符号链接；不对被拒绝条目产生回调。
- **语言依赖**：**已支持**。
- **设计缺口**：**有（非语言）**：必须先落共享 walker 再实现两个宿主版本。
- **来源**：proposal §3.3；analysis §3.5、§3.15、§7.9；design #9。

### 2.4 横切约束

#### R-14 `errno → FS_ERR_*` 映射与内存

- **要解决**：`char *` 原语只返回 -1，`FS_ERR_*` 分类没有来源；`strdup` 不是 C99，严格 C99/Linux 下可能不可用（评估 §2.8、§3.11、§7.12）。
- **验收判据**：
  1. 全包只有一个 `fsguard_errno_to_code(int)`；errno→code 分支只出现在该函数（可核对）。
  2. `ENOENT` / `ENOTDIR` → `NOT_FOUND`；`EACCES` / `EPERM` → `PERMISSION`；`EISDIR` → `IS_DIR`；其余 → `IO`（运行四类夹具 + 表可核对）。
  3. `FS_ERR_OOM` 只在 `malloc` / `fsguard_strdup` 失败时使用（可核对）。
  4. 包内提供 `fsguard_strdup`（`malloc + memcpy + NUL`）；`.ct` / `.shim.h` 中不直接调用 libc `strdup`（grep 命中数 = 0）；在 `cc -std=c99 -Wall -Wextra` 下无隐式声明（编译作为附加证据，不作为唯一判据）。
  5. 偏移量用 `long long` / `int64_t`，公开面不出现 `long` 偏移（可核对）。
- **非目标**：不定义平台特有的 errno 扩展；不把 errno 数字暴露给消费者；不做错误码字符串 ABI。
- **语言依赖**：**已支持**。
- **设计缺口**：无。
- **来源**：proposal §2.3；analysis §2.8、§3.11、§7.12；design #12。

#### R-15 平台范围：MVP 仅 POSIX

- **要解决**：提案 §5 的 P2 Win32 分层容易在 MVP 被顺手做进来，导致路径语义分叉。
- **验收判据**：
  1. MVP 实现内无 Win32 分支（`grep -i win32` 仅出现在文档）。
  2. 不创建 `ct-fsguard-win32` 实现目录（可核对）。
  3. 路径分隔符只接受 `/`；输入 `a\b` 按字面字符处理，不做转换（运行）。
- **非目标**：Win32、盘符、大小写折叠、`\` 分隔符、跨平台自动统一；P2 分包不建。
- **语言依赖**：**已支持**（`-I` 选实现包的分层约定，与 ct-process 一致）。
- **设计缺口**：无。
- **来源**：proposal §5、§9.5；analysis §5。

#### R-16 不替代也不修改 `std::fs`

- **要解决**：提案 §1 明确"不是 std::fs 的替代品"，需要可核对的边界，避免实现漂移成平行 API。
- **验收判据**：
  1. `ct-pkg/std` 零改动（该仓 diff 为空）。
  2. 本包不在 `char *` 上暴露 `exists` / `readFile` / `writeFile` / `list` 同名方法（可核对）。
  3. README 的"能力对照表"与实现列出的方法一一对应（可核对）。
- **非目标**：不改 `std::fs` 行为或签名；不复制其实现；不做兼容 shim。
- **语言依赖**：**已支持**。
- **设计缺口**：无。
- **来源**：proposal §1、§8 冻结面；analysis §2.6。

#### R-17 夹具与门禁

- **要解决**：验收判据必须可执行，且历史教训是"只数次数 / 只比指针"会假绿（评估 §4）。
- **验收判据**：
  1. 运行时生成夹具：300 字节序列文件、含 NUL 二进制、固定树（root + 3 目录 + 5 文件）、20 层深树、chmod 000 目录/文件；仓库内无二进制 fixture（可核对）。
  2. 至少一个**可运行示例**纳入门禁：示例失败则门禁失败（可核对门禁退出码）。
  3. 一条门禁命令覆盖 R-01…R-16 的全部运行断言；失败时输出失败用例编号（R 编号 + F/N/G 编号）。
  4. 连续两次运行结果一致（无顺序依赖）；集合类断言排序后比较。
  5. ASan/LSan 作为门禁一环，覆盖 R-08、R-11、R-13 的所有权用例。
- **非目标**：不做性能基准；不做多平台 CI 矩阵；不做模糊测试。
- **语言依赖**：**已支持**。
- **设计缺口**：无。
- **来源**：proposal §6；analysis §4 末行。

## 3 评估判定"原提案不成立、必须先改"

### 3.1 三处硬伤

| 编号 | 原文口径 | 为什么不成立 | 改后口径 | 状态 |
| --- | --- | --- | --- | --- |
| H-1 | `pub trait FsGuardOps for char * { … }`（proposal §2.1） | `.m.ct` 的 `pub trait` 只写抽象方法，类型宿主必须由 `map trait … for type char *` 绑定；不存在 `pub trait X for char *` 形式（analysis §2.1） | 拆 `FsGuardOps.m.ct`：`pub trait` + `map trait`；方法体放 `.shim.h` 的 `static inline`（R-01） | **已定**（语言形态强制，无选择空间） |
| H-2 | 10 个 `#define FS_*`（proposal §2.3） | CT 无预处理器；`#define` 只在 `.m.ct` prologue / `#ct-raw` 透传，`.h.ct` 不能靠它定义 CT 常量（analysis §2.3） | `pub enum FsErrCode`，10 个成员数值冻结（R-02） | **已定**（语言形态强制） |
| H-3 | 词法 `check` + `fopen` 跟随链接，仍称"沙箱"，`R6` 写"MVP 不拦截 symbol link" | `/workspace/src/evil -> /etc` 通过词法检查后可读 `/etc/passwd`，称沙箱即虚假安全承诺（analysis §3.8） | 采用评估方案 B：**明确降级为词法策略层，不是安全边界**；不 `lstat` / 不 `realpath` / 不 `openat`；全包与文档删除"沙箱 / sandbox"表述（R-09、R-16） | **已定（行为）**，依据 `README.md` 边界行；对外表述作废需提案方确认 → **Q-1** |

### 3.2 12 条必须先改项

| 编号 | 条目（analysis §7） | 改后口径 | 状态 | 落到需求 |
| --- | --- | --- | --- | --- |
| C-01 | trait 形态 | `pub trait` + `map trait … for type char *`，方法体 `.shim.h` | 已定 | R-01 |
| C-02 | `FsWalkCb` 位置 | 从 `.m.ct` 的 `pub typedef` 移到 `.h.ct`（`.m.ct` 不产出头） | 已定 | R-01 |
| C-03 | `#define` 常量 | `pub enum FsErrCode`，10 个成员冻结 | 已定 | R-02 |
| C-04 | `_policy_enabled` 与 check 错误码 | 派生式（三指针任一非 NULL）；root/allow 越界 `OUT_OF_BOUNDS`，deny `DENIED_PATTERN` | 已定（错误码表中仅这两个语义匹配，无第二候选） | R-09 |
| C-05 | 绝对/相对 `..` 规则 | 绝对路径在根处钳住（`/../etc` → `/etc`）；相对路径保留前导 `..`；两处共用 | **待确认 Q-3**（建议口径已写入 R-05 表） | R-05、R-06、R-09 |
| C-06 | 符号链接策略 | 方案 B：词法策略层，非安全边界，不解析链接 | 已定（`README.md` 边界行）；表述确认 → Q-1 | R-09、R-16 |
| C-07 | `FsGuard` 显式 `impl Drop` | 释放四个 `char*`（含 `_last_error.path/message`） | 已定 | R-08 |
| C-08 | `last_error` 契约 | 只读借用；`FsError*` 与 `path`/`message` 下次操作后失效；`clear_error` 置 NULL | 已定 | R-11 |
| C-09 | `walk` 契约 | root 先 check；depth 0 = root；回调非 0 原值返回；不可读目录 fail-closed 中断；deny 子树跳过 | 已定（签名部分 → Q-4） | R-07、R-13 |
| C-10 | glob 方言 | `*`/`?` 不跨 `/`；大小写敏感；全路径匹配；目录命中跳整棵；MVP 无 `**` | **待确认 Q-7** | R-10 |
| C-11 | 容量与偏移边界 | `cap` 含 NUL（`cap-1` 成功 / `cap` 失败）；`normalize_to` 容量不足置空串首字节；偏移用 `long long`/`int64_t` | 已定 | R-04、R-05、R-12 |
| C-12 | errno 映射与 `strdup` 降级 | 单一 `fsguard_errno_to_code`；包内 `fsguard_strdup` | 已定 | R-14 |

### 3.3 提案 §9 五个待确认问题的处置

| 提案 §9 | 处置 | 落到需求 |
| --- | --- | --- |
| 1. `FsGuard *` 与 `char *` 方法是否零冲突 | **已定：是**。22 个已占名字中四名均未占用；第三方同名需限定调用。 | R-03 |
| 2. `std::fs::list` 返回顺序是否稳定 | **已定：不承诺**。按 `readdir` 顺序，夹具只断言集合相等。 | R-07、R-13 |
| 3. `readFile` 的 cap 语义是否直接复用 | **已定：语义复用，错误不转发**。`cap` 含 NUL、不足返回 -1 不截断；但本包必须自己 `stat`/`errno` 映射。 | R-12 |
| 4. `FsWalkCb` 是否加 `long size` | **已定：MVP 不加**（P2 再议）；但 `walk` 需加 `max_depth`。 | R-07 |
| 5. Win32 平台包是否本轮范围 | **已定：否**，仅 POSIX；P2 分包不建。 | R-15 |

### 3.4 本次新发现的需求缺口（评估未覆盖）

| 编号 | 缺口 | 处置 | 落到需求 |
| --- | --- | --- | --- |
| G-1 | `write_file` 完全未被评估：半截文件、截断、二进制、越界时文件是否被创建，均无口径 | 判据 1–4 已写（二进制、越界不创建）；失败后文件状态 → **Q-2** | R-12 |
| G-2 | `check` 是否访问文件系统未定义。评估 §3.11 要求 `stat` 映射错误，易被误读成 `check` 要 `stat` | 冻结：`check` 纯词法不 `stat`；`FS_ERR_NOT_FOUND` 只由读/写/遍历产生 | R-09 |
| G-3 | `has_error()` / `last_error()` 与 `check` 返回值的关系未定义：失败是否置错、成功是否清错 | 冻结：每次公开操作开始清错；失败（含 `check` 失败）置错；成功后可观测为无错 | R-11 |
| G-4 | 配置 setter 非法参数（`max_depth < 0`、空指针）的返回值与错误码未定义 | 冻结：返回 NULL 且不改状态；错误码 → **Q-5** | R-08、R-10 |
| G-5 | `_root` / `_allow_prefix` 是否规范化后存储未定义；不规范化会导致 `new("/ws/../ws")` 与 `new("/ws")` 行为不同 | 冻结：`new` 与 setter 内先规范化再存储 | R-08 |

## 4 待确认

> 以下 7 条每条已给建议口径，未确认前按建议口径写判据；提案方确认或否决后只改对应一条。
> 其中 Q-1 涉及对外主张，优先级最高。

| 编号 | 待确认内容 | 建议口径 | 不确认会卡住什么 |
| --- | --- | --- | --- |
| Q-1 | 是否确认放弃"沙箱 / 安全边界"主张，采用"词法策略层" | 放弃。依据 `README.md` 边界行；提案 §1/§3.1/§6 及 F8"越界"表述中的"沙箱"语义作废 | 卡住包名与 README 对外表述；若反选"真沙箱"，R-09 需加 `lstat`/`realpath`/`openat`，R-12 不能复用 `std::fs`，夹具与依赖面整体重做 |
| Q-2 | `write_file` 失败时的文件状态：是否允许半截文件、失败前是否截断、是否要求原子写 | MVP 非原子：先 `check` 再 `open`，失败不保证回滚，但**越界时不得创建文件**；README 写明"失败可能留下部分内容" | 卡住 R-12 判据 3/4 的断言（失败后文件内容无法定值）与 README 行为承诺 |
| Q-3 | `..` 消解规则：绝对路径在根处钳住、相对路径保留前导 `..` | 采纳评估 §3.1 建议（R-05 表已按此写） | 卡住 R-05 输出表、R-06 的 `../etc` 用例、R-09 的规范化后比较基准；改规则即改全部相关期望值 |
| Q-4 | `char *::walk` 是否可改为 `walk(cb, ud, max_depth)`（破坏提案 §2.1 三参数调用示例） | 可改：共享 walker 必须能表达深度，三参数形式写不出 `max_depth=0` 的判据 | 卡住 R-07 的 API 冻结与 F5 深度用例；若不许改，深度限制只能落在 `FsGuard` 一侧，R-07 判据 3 需删除 |
| Q-5 | 是否允许第 11 个错误码 `FS_ERR_INVALID`（负 offset、非法 setter 参数） | 不新增：负 offset 与 `len<0` 返回 -1 + `FS_ERR_IO`，`len==0` 返回 0，`max_depth<0` 返回 NULL + `FS_ERR_IO`；保持 10 码冻结 | 卡住 R-04 判据 4、R-08 判据 5、R-10 判据 5 的具体错误码；若要求可辨识的 INVALID，需在 G0 前追加第 11 码（成本低，但破坏"10 码冻结"表述） |
| Q-6 | 绝对 `_root` + 相对输入路径：拒绝还是按 root 解析 | MVP 拒绝：返回 `FS_ERR_OUT_OF_BOUNDS`；P2 再议"相对按 root 解析" | 卡住 R-09 判据 7；选择不同会导致同一输入两种结果，无法写唯一期望值 |
| Q-7 | deny glob 方言：MVP 是否接受"无 `**`、`*`/`?` 不跨 `/`、全路径匹配、目录命中跳整棵" | 接受最小集；`fnmatch` + `FNM_PATHNAME` 即可实现，`**` 留 P2 | 卡住 R-10 判据 3 与提案 R7 的"匹配结果可预期"；方言未定则所有 deny 用例期望值不可写 |

## 5 全局非目标

以下不属于本包需求，任何需求实现都不得顺手引入：

| 非目标 | 依据 |
| --- | --- |
| 文件锁、内存映射、异步 I/O、watch/notify | proposal §1 |
| 符号链接解析（`lstat` / `realpath` / `openat(O_NOFOLLOW)`） | README 边界行；analysis §3.8 方案 B |
| ACL、权限位策略 | proposal §1 |
| 跨平台路径自动统一；Win32 / 盘符 / 大小写折叠 | proposal §1、§5、§9.5 |
| 替代或修改 `std::fs` | proposal §1、§8 冻结面；R-16 |
| 方法重载、语言关键字、编译器改动 | analysis §5；R-01 |
| L1 自定义 `[]` 下标 | analysis §5（`path[0]` 是 C 解引用，与本包无关） |
| 原子写、`fsync`、并发遍历 | R-12、R-13 非目标 |

## 6 追溯矩阵：提案验收用例的处置

| 提案用例 | 归属 | 处置 |
| --- | --- | --- |
| F1 `src/../a.c` → `a.c` | R-05 | 保留；补绝对路径、`/`、尾斜杠、重复 `/`、容量不足 |
| F2 / F3 `read_chunk` 0 / 100 | R-04 | 保留；夹具改为运行时生成 300 字节，不依赖仓库大文件 |
| F4 EOF 返回 0 | R-04 | 保留；补 `offset == EOF`、`len = 0`、负 offset |
| F5 `walk` 回调计数 | R-07 | **改写**：只数次数会假绿，改为 `(path, is_dir)` 集合比较 |
| F6 / F7 `is_under` | R-06 | 保留；补相等、prefix 尾斜杠、`../etc` |
| F8 越界 `read_file` | R-09、R-12 | 保留；断言 `code` / `path` / `message`；补 root 自身允许 |
| N1 / N2 同文件共存 | R-03 | 原文形态编译不过；按改后形态保留，并加运行断言与同名冲突负例 |
| N3 `../etc/passwd` | R-05、R-06 | 保留但只覆盖相对路径；补绝对钳根用例 |
| N4 offset 超文件 | R-04 | 保留；补负 offset、`offset == EOF`、目录路径 |
| N5 回调非 0 中断 | R-07 | 保留；补 root 回调中断、返回原值 |
| N6 缓冲区不足 | R-12 | 保留；补 `cap-1` / `cap` 两个边界、不写半截、读写分开测 |
| N7 `last_error` 指针失效 | R-11 | **改写**：不比 `e1` 地址，改断言 `path` 内容已变 + ASan |
| （缺）`write_file` | R-12 | 提案 §6 无任何 `write_file` 用例，本次新增 |
| （缺）`check` 纯词法 | R-09 | 本次新增：不存在路径 `check` 返回 `FS_OK` |
| （缺）`new(NULL)` / drop 泄漏 / deny 目录 / 不可读目录 | R-08、R-10、R-13 | 本次新增 |

## 7 关联文件

- 提案原文：[proposal.md](proposal.md)（未改动）
- 评估结论：[analysis.md](analysis.md)
- 设计待决项：[design.md](design.md)
- 边界声明：[README.md](../README.md)
