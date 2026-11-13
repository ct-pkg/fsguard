# ct-fsguard 设计待决项

> 状态：评估已完成，未立项。以下 12 条来自 [评估结论](analysis.md) 第 7 节。
> 每条一行：条目 / 现状 / 不做会怎样 / 影响阶段。

| # | 条目 | 现状 | 不做会怎样 | 影响阶段 |
| --- | --- | --- | --- | --- |
| 1 | `pub trait FsGuardOps for char *` 改为 `pub trait` + `map trait … for type char *` | 单文件 `pub trait … for char *` 不是合法 CT 形态；类型宿主必须用 `map trait`，方法体放 `.shim.h` | 整份 API 编译不过 | G0a |
| 2 | `FsWalkCb` 从 `pub typedef` 移到 `.h.ct`（或 `.m.ct` 的 `pub type`） | `.m.ct` 不产出头，消费者看不到这个函数指针类型 | `walk` 的签名无法跨单元使用 | G0a |
| 3 | 10 个 `#define` 改成 `pub enum FsErrCode` | CT 没有预处理器；`.h.ct` 不能靠 `#define` 定义 CT 常量 | 错误码不可被 CT 识别，跨单元不可用 | G0a / G2 |
| 4 | 补 `_policy_enabled` 定义并冻结 `check` 错误码 | 结构体没有该字段；root/allow/deny 越界各报什么码未定 | `check` 行为不可测，F/N 用例无法断言 | G0b / G3 |
| 5 | 冻结绝对/相对 `..` 规则 | §3.4、R2、N3 三处不一致；绝对路径多出的 `..` 是钳根还是保留未定 | `normalize_to` / `is_under` 结果随实现漂移 | G0b / G1 |
| 6 | 决定符号链接策略 | 词法 `check` + `fopen`/`opendir` 跟随链接；`R6` 写“MVP 不拦截” | `src/evil -> /etc` 可越界读；包不能称为安全边界 | G0b / G1 / G4 |
| 7 | 补 `FsGuard` 的显式 `impl Drop` | 目前只有 `use Drop`；编译器不会自动释放 `char *` 字段 | `_root` / `_allow_prefix` / `_deny_pattern` / `_last_error` 全泄漏 | G2 |
| 8 | 定 `last_error` 契约 | “下次操作后失效”未说清是结构指针还是 `path`/`message` 内容；无错误时返回什么也未定 | N7 只比指针会假绿；调用方缓存 `path` 会 UAF | G0b / G2 / G4 |
| 9 | 定 `walk` 契约 | root 是否 check、`max_depth=0`、不可读子目录、deny 目录、符号链接都未定；`char *::walk` 没有深度参数 | `walk` 行为不可复现，深树可能栈溢出/越界 | G0b / G1 / G4 |
| 10 | 定 `deny_pattern` 的 glob 方言 | `*` 是否跨 `/`、`**`、大小写、全路径 vs basename、目录是否匹配均未定义 | R7 与验收用例无法写，匹配结果不可预期 | G0b / G3 |
| 11 | 定容量与偏移边界 | `read_file` 的 cap 边界、`read_chunk` 负 offset/EOF/`len<=0`、`normalize_to` 的 cap 均未定 | 边界用例假绿或写越界；`long` 在 32 位平台截断 | G0b / G1 / G4 |
| 12 | 补 `errno → FS_ERR_*` 映射与 `strdup` 降级 | `char *` 原语只返回 -1，错误码来源未定义；`strdup` 依赖 POSIX/C99 可见性 | 错误码不可靠；严格 C99 的 Linux 可能编译失败 | G1 / G2 / G4 |
