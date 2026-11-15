# ct-fsguard 使用教程（API 草案）

> **能不能跑：不能。** `README.md:7` 写明"代码待立项后开"；仓库没有实现、没有包目录、没有门禁（`AGENTS.md:266`）。下面所有代码都是按 `docs/proposal.md:29-86` 与 `docs/requirements.md` 的草案形态写的，**整个包标记为 `未实现`**；片段里额外标 `待定` 的地方，是需求本身还没冻结的能力。
> **边界：** 这是词法策略层，不是安全边界；不解析符号链接（`README.md:6`）。
> 调用形态说明：草案以 `FsGuard::new(...)` 表示 static 工厂、以 `g->method(...)` 表示实例调用；包未实现，最终语法以 G0a 冻结为准。

## 0 入门路径总览

五个场景可以连成一条从"最小可用"到"知道边界在哪"的路径：

| 步 | 场景 | 你得到什么 | 前置 |
| --- | --- | --- | --- |
| 1 | A 分块读 | 不把大文件读进内存，能判断 EOF | 无状态原语 |
| 2 | B 受限读写 | 根目录内读写，失败有错误码和原因 | A + `FsGuard` |
| 3 | C 先判定再操作 | 在 I/O 之前判断"这个路径能不能进" | B + `check` |
| 4 | D 受控遍历 | 批量列目录，可限制深度、跳过黑名单 | B + `walk` |
| 5 | E 并发与竞态 | 知道哪些事这个包保证不了、不能拿它当安全边界 | A–D 全部 |

这条路径能连起来，是因为每一步只增加一个能力面：无状态原语 → 有状态包装 → 预判 → 批量 → 边界。反过来，如果你第一步就需要"安全隔离"，这个包现在不适用，直接看场景 E。

## 1 场景 A：从大文件里分块读（最小可用）

**用户想干什么**：日志或二进制文件很大，不想一次性读入；希望从指定偏移读固定长度，并能判断什么时候读完。

**怎么写**（草案，未实现）：

```ct
import std::fsguard::FsGuardOps;

char buf[4096];

int n = "big.log".read_chunk(0, buf, 4096);
if (n < 0) {
    // 草案：char * 原语只返回 -1，没有 FsError，无法区分原因（R-14）
} else if (n == 0) {
    // EOF：offset 已到或超过文件末尾
} else {
    // n 是实际字节数；不自动补 NUL，二进制安全
}

int m = "big.log".read_chunk(4096, buf, 4096);
```

**得到什么结果**：`n` 是实际读到的字节数；读完或越界时返回 0；含内嵌 NUL 的内容逐字节原样返回（`requirements.md:74-80`）。公开面的偏移量期望是 `long long` / `int64_t`，提案里的 `long` 已被 R-04 判据 6 取代。

**出错时会看到什么**：只有 `-1`，没有错误码。负 offset 也返回 -1，但它的分类挂在 Q-5 上（`待定`）。要区分"不存在 / 无权限 / 是目录 / IO 错"，必须换用 `FsGuard` 的包装（场景 B）。

**状态**：分块读本身已定；`待定`：Q-5 决定负 offset 的错误码。整个 API `未实现`。

## 2 场景 B：受限目录内读写（加防护）

**用户想干什么**：只允许在 `/workspace` 下读写；越界路径必须被拒绝；失败时能拿到具体原因。

**怎么写**（草案，未实现）：

```ct
import std::fsguard::FsGuard;
import std::fsguard::FsGuardOps;

FsGuard *g = FsGuard::new("/workspace");   // root 规范化后存储；NULL 表示不做根约束

char buf[256];
int n = g->read_file("/workspace/src/a.c", buf, 256);
if (n < 0) {
    FsError *e = g->last_error();
    if (e != NULL) {
        if (e->code == FS_ERR_OUT_OF_BOUNDS) {
            // 越界，先于 I/O 返回（R-12 判据 6）
        } else if (e->code == FS_ERR_BUFFER_TOO_SMALL) {
            // 文件 >= cap 字节；cap 含 NUL（R-12 判据 1）
        } else if (e->code == FS_ERR_NOT_FOUND) {
            // 不存在
        } else if (e->code == FS_ERR_PERMISSION) {
            // 无权限
        } else if (e->code == FS_ERR_IS_DIR) {
            // 是目录
        }
    }
}

char data[4];
data[0] = 'a'; data[1] = 0; data[2] = 'b'; data[3] = 'c';
int w = g->write_file("/workspace/out.bin", data, 4);
if (w < 0) {
    // 越界：FS_ERR_OUT_OF_BOUNDS，且目标文件不会被创建（R-12 判据 4）
}

delete g;
```

**得到什么结果**：`read_file` 的 `cap` 含 NUL，文件 `cap-1` 字节成功、`cap` 字节失败且缓冲区不被写半截；`write_file` 写 `len` 字节，内嵌 NUL 也原样落盘；越界路径在 I/O 之前被拦下（`requirements.md:209-215`）。工厂返回值用 `delete`，不要用 `own`（`:151`）。

**出错时会看到什么**：`-1` + `last_error()`；`code` 是 10 个 `FS_ERR_*` 之一，`path` 是规范化后的路径，`message` 非空（`:195`）。`last_error()` 是借用，下一次 `FsGuard` 操作后就失效；要保留必须自己复制（`:193`）。`clear_error()` 之后 `last_error() == NULL`（`:197`）。

**待定**：
- `write_file` 成功时的返回值草案没写，判据只冻结了失败返回 -1（`requirements.md:208-215`）。
- 失败后是否允许留下半截文件由 Q-2 决定（`:344`）。
- `new` 分配失败如何报告也未定义：没有对象就没有 `last_error`，只能看到 `NULL`（本次观察，盘点未单列，建议并入 G0b 冻结）。

**状态**：读写判据已定；`待定`：Q-2、Q-5、`write_file` 成功返回值、`new` 失败报告。整个 API `未实现`。

## 3 场景 C：先判定，再操作（不放行越界路径）

**用户想干什么**：在真正打开文件之前，先判断路径是否在允许范围内；或者只做规范化，不碰文件系统。

**怎么写**（草案，未实现）：

```ct
import std::fsguard::FsGuard;
import std::fsguard::FsGuardOps;

char norm[256];
int rc = "src/../a.c".normalize_to(norm, 256);
// rc == 0，norm == "a.c"；cap 不足时 rc == -1 且 out[0] == 0

int under = "/workspace/src/a.c".is_under("/workspace/src");
// 1；"/workspace/src2/a.c" 得到 0（按段边界，不是字符串前缀）

FsGuard *g = FsGuard::new("/workspace/src");
int c1 = g->check("/workspace/src/../src2/a.c");
// c1 == FS_ERR_OUT_OF_BOUNDS：先规范化，再按段边界判 root

int c2 = g->check("/workspace/src/not-on-disk");
// c2 == FS_OK：纯词法，不访问文件系统

if (c1 != FS_OK) {
    FsError *e = g->last_error();
    // e->path 是规范化后的路径，e->message 非空
}

delete g;
```

**得到什么结果**：规范化输出见 `requirements.md:90-101` 的九行表；`is_under` 相等也返回 1，`/workspace/src2` 不算 `/workspace/src` 之下（`:115-120`）；`check` 的判定顺序是 规范化 → root → allow → deny → OK，越界和 deny 同时成立时先报 `OUT_OF_BOUNDS`（`:161-167`）。

**出错时会看到什么**：`check` 直接返回错误码，同时写入 `last_error`（`:168`）；`check` 永远不会返回 `FS_ERR_NOT_FOUND`，因为不看磁盘（`:166`）。`normalize_to` 容量不足返回 -1 并把 `out[0]` 置 0，不写半截（`:103`）。

**待定**：
- Q-3 决定绝对路径在根处钳住、相对路径保留前导 `..` 的规则（`requirements.md:345`）。
- Q-6 决定"绝对 root + 相对输入"是拒绝还是按 root 解析（`:348`）。
- Q-7 决定 deny glob 的方言（`:349`）。
- 原文 R-06 判据 1 的示例用的是相对路径 `src/a.c` 对绝对 `/workspace/src`；在 Q-6 冻结前，本教程只用绝对路径演示段边界，避免把未定口径当成结论。

**状态**：`待定`：Q-3、Q-6、Q-7。整个 API `未实现`。

## 4 场景 D：受控遍历（deny + 深度）

**用户想干什么**：递归列一个目录，但要限制深度、跳过敏感子树，并且能在回调里主动中止。

**怎么写**（草案，未实现）：

```ct
import std::fsguard::FsGuard;
import std::fsguard::FsGuardOps;

static int on_entry(char *entry, int is_dir, void *ud) {
    // entry 只在本次回调内有效；跨回调保存必须自己复制
    if (is_dir) {
        // 目录
    }
    return 0;   // 非 0：walk 立即中断，原值返回
}

FsGuard *g = FsGuard::new("/workspace");
g->deny_pattern("/workspace/secret");   // 命中目录 → 整棵子树不回调
g->max_depth(8);                        // 默认 16；0 只回调 root

int rc = g->walk("/workspace", on_entry, NULL);
if (rc < 0) {
    FsError *e = g->last_error();
    // 不可读子目录：fail-closed，期望 FS_ERR_PERMISSION
}

delete g;
```

**得到什么结果**：root 自己先被回调一次且 `is_dir == 1`；`max_depth=0` 只回调 root，`max_depth=1` 回调 root + 直接子项；回调返回 7 时 `walk` 返回 7 且之后 0 次回调（`requirements.md:131-134`）。deny 命中的目录整棵子树 0 次回调；不可读子目录按 fail-closed 中断并返回 -1 + `FS_ERR_PERMISSION`（`:225-228`）。遍历顺序不承诺，断言要排序后比集合（`:230`）。

**出错时会看到什么**：root 越界返回 -1 且 0 次回调；不可读子目录返回 -1 + `FS_ERR_PERMISSION`；回调主动中止时返回的是回调原值（例如 7），不是 -1，不要混为一谈（`:225-228`、`:134`）。

**待定**：
- Q-4 决定 `char *::walk` 是否增加 `max_depth` 参数（`requirements.md:346`）；本场景用的是 `FsGuard::walk(char *root, FsWalkCb cb, void *ud)`，它的形态已定。
- Q-7 决定 deny glob 方言（`:349`）；示例只用"命中目录名"的字面 pattern。

**状态**：`FsGuard::walk` 判据已定；`待定`：Q-4、Q-7。整个 API `未实现`。

## 5 场景 E：并发、竞态与"失败时放行"

**用户想干什么**：多个线程共享一个 `FsGuard` 做检查；或者 `check` 通过之后再读写；或者想确认失败时包会不会自动放行。

**怎么写**（这不是可用代码，`未实现` / `未定义`）：

```ct
FsGuard *g = FsGuard::new("/workspace");

// 未实现：FsGuard 没有线程安全承诺（R-08 非目标：不做线程安全）
// 两个线程共享 g 调用 read_file/walk 时，last_error 会被互相覆盖；
// 包内没有锁、没有每线程副本、没有可重入保证。
```

```ct
char buf[256];
if (g->check("/workspace/src/a.c") == FS_OK) {
    // 到这里之后、read_file 打开之前，别的进程可以把 a.c 换成
    // 指向 /etc/passwd 的符号链接；read_file 会跟随链接。
    // 词法层无法阻断，也不会报错（analysis §3.8）。
    g->read_file("/workspace/src/a.c", buf, 256);
}
```

**得到什么结果**：`check` 说"允许"，不代表实际打开的文件还在 root 下。符号链接、硬链接、挂载点、`check` 与 `open` 之间的替换（TOCTOU）都不在包的防护范围内（`analysis.md:35`；盘点 CG-02/04/06）。共享 `FsGuard` 时错误状态会互相覆盖，结果不可复现（CG-09）。

**出错时会看到什么**：**可能什么都看不到**。越界读取可能成功返回字节数，`last_error` 为空；这正是"词法策略层不是安全边界"的含义（`README.md:6`）。

**失败时放行还是拒绝**：
- `check` 返回非 0 时，包不会替你停；拒绝是调用方的责任。
- `read_file` / `write_file` 内部会先 `check`，越界不落 I/O（`requirements.md:214`）。
- 遍历遇到不可读子目录是显式 fail-closed（`:228`）；其他 `list`/读失败没有统一口径（CG-07）。
- 没有 fail-open 开关，也没有"失败时继续"的配置项。

**状态**：`未定义（明确不做）`：线程安全、TOCTOU、符号链接、硬链接、挂载点、超长路径、可重入；`待定`：失败策略的统一口径（CG-07/08）。

## 6 场景能力对照

| 场景 | 用到的需求 | 已定部分 | 待定 / 未实现 |
| --- | --- | --- | --- |
| A 分块读 | R-04、R-14 | 偏移、EOF、二进制安全、64 位偏移 | Q-5 负 offset 错误码；整个 API `未实现` |
| B 受限读写 | R-02、R-08、R-11、R-12、R-14 | 边界、errno 映射、借用的 `last_error`、Drop | Q-2 半截文件；Q-5 非法参数码；`write_file` 成功返回值；`new` 失败报告；整个 API `未实现` |
| C 先判定再操作 | R-05、R-06、R-09、R-10 | 九行规范化表、段边界、判定顺序、纯词法 | Q-3、Q-6、Q-7；整个 API `未实现` |
| D 受控遍历 | R-07、R-10、R-13 | root 回调、深度语义、回调原值返回、deny 子树、fail-closed | Q-4 `char *::walk` 签名；Q-7 glob 方言；整个 API `未实现` |
| E 并发与竞态 | R-08、R-09、R-16 | "不做线程安全"、"不是安全边界"已明文 | 线程安全、TOCTOU、链接/硬链接/挂载点/长路径、可重入：`未实现`；CG-02/03/04/05/06/09/10 |

## 7 教程收束：从最小可用到带防护

1. **A 只依赖无状态原语**：适合"读一个大文件的一段"，不需要任何策略对象。
2. **B 增加 `FsGuard`**：从"能读"变成"只在根下读写，失败有分类"；这也是大多数调用方真正需要的第一层保护。
3. **C 把判定提前**：适合 UI 预览、批处理预检、批量任务开始前的准入检查；注意它不碰磁盘，`FS_OK` 不等于文件存在。
4. **D 扩展到目录**：深度、deny、回调中断、借用契约都在这一步；遍历顺序不承诺，测试要比集合。
5. **E 明确边界**：需要真正的安全隔离、并发共享、原子写或多平台路径语义时，这个包现在不提供；不要用 `check` 冒充安全边界（D-012）。

一句话：**A→D 是"可用的策略与便利层"，E 是"到此为止"的说明。** 如果用户的场景从 E 开始，先按盘点文档补齐 CG-02…CG-06、CG-09/10 并用两席评审冻结，再谈使用。
