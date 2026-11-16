# ct-fsguard roadmap（草案）

> 状态：draft。依据 D-001…D-005 与 `docs/acceptance/fsguard-status.md`。  
> 本文件只排相与退出概要，**不建 phase 卡、不改代码**。

## 0 结论

需求已可进入 roadmap 与 phase 规划，但不能进入实施：17 条中 15 条可验收、2 条部分可验收（R-02/R-17）。**PH-01 是「路径词法与错误枚举」起步相。**

## 1 相划分

| 相 | 目标 | 覆盖 R | 前置相 | 退出判据概要 |
| --- | --- | --- | --- | --- |
| PH-01 | 路径词法与错误枚举 | R-02、R-05、R-06、R-09 | 无 | 九行规范化表、绝对段边界、check 顺序与码、10 码枚举冻结 |
| PH-02 | 无状态原语、读写与错误面 | R-04、R-08、R-11、R-12、R-14 | PH-01 | offset/EOF/二进制、生命周期、FsError 契约、读写边界、errno 映射 |
| PH-03 | 遍历与策略 | R-07、R-10、R-13 | PH-02 | 三参数 walk/深度/借用、deny 最小方言、deny 子树与 fail-closed |
| PH-04 | 包形态、平台与门禁 | R-01、R-03、R-15、R-16、R-17 | PH-01…PH-03 | 包形态/命名共存、POSIX 边界、std::fs 零改动、夹具与平台化门禁 |

覆盖核对：4 + 5 + 3 + 5 = 17，无遗漏、无重复归属。

## 2 各相说明

### PH-01 路径词法与错误枚举（起步）

- **目标**：先把 `normalize_to`、`is_under`、`check` 与 `FsErrCode` 冻结成可判定的词法核心。
- **覆盖**：R-02、R-05、R-06、R-09。
- **退出判据概要**：
  - R-05 九行表逐行 assert；`cap` 边界与 `out[0]==0`。
  - R-06 只用绝对路径做段边界（D-002）；R-09 顺序与错误码冻结。
  - R-02 十码冻结；`FS_ERR_NOT_DIR` 在「映射到 `ENOTDIR`」或「删除成员」中二选一并补判据。
  - 新增 R-05 的 `out`/`path` 重叠检测（FSR-16），不能只靠 README 禁止。
- **前置**：D-001、D-002、D-003 已裁；roadmap 批准。

### PH-02 无状态原语、读写与错误面

- **目标**：落 `read_chunk` 与 `FsGuard` 的 `read_file` / `write_file`，把 errno 映射和生命周期收口。
- **覆盖**：R-04、R-08、R-11、R-12、R-14。
- **退出判据概要**：
  - R-04 offset/EOF/负值/二进制/NUL 用例；公开偏移为 `long long`/`int64_t`。
  - R-08 工厂/`delete`/setter 链式/非法参数；ASan 下无重复释放。
  - R-11 借用失效、`clear_error`、`check` 失败置错；LSan（Linux）无泄漏。
  - R-12 读写边界、越界不落 I/O；Q-2 裁定后补失败后文件状态断言。
  - R-14 四类 errno 映射；补 `ELOOP` 归类与环用例。
- **前置**：PH-01；Q-2 必须在 R-12 退出前裁定。

### PH-03 遍历与策略

- **目标**：落 `char *::walk` 与 `FsGuard::walk`，把深度、deny 与 fail-closed 写死。
- **覆盖**：R-07、R-10、R-13。
- **退出判据概要**：
  - R-07 三参数签名（D-004）、`max_depth=0/1/16`、回调中断、借用契约。
  - R-10 默认深度 16、覆盖语义、deny 最小方言（D-005）、空串未配置。
  - R-13 root 回调、deny 子树 0 回调、不可读子目录 fail-closed、共用 walker。
  - 补 FSR-15：walk 根不存在 → -1 + 冻结码、0 回调。
- **前置**：PH-02；D-004、D-005 已裁。

### PH-04 包形态、平台与门禁

- **目标**：把包形态、命名共存、POSIX 边界与门禁收口，形成可交付包。
- **覆盖**：R-01、R-03、R-15、R-16、R-17。
- **退出判据概要**：
  - R-01 `pub trait` + `map trait` + `.h.ct` 回调；包内 `#define` 计数 0。
  - R-03 四个方法名与 22 个 std 名字无交集；判据 1/2/3 由 `g3-ph04 r03` 的三个用例覆盖（共存、限定调用、未限定调用必须歧义）。~~判据 3 依赖共享库机制落地后才转门禁，期间保持未实施~~（2026-11-16 复核：ct v0.62.0 已支持同一宿主多 trait 与限定调用，该挂起理由作废，见 D-014/B-003）。
  - R-15 只接受 `/`；`a\b` 字面处理；无 Win32 分支。
  - R-16 `std::fs` 零改动；不暴露同名方法。
  - R-17 夹具运行时生成、入门禁；macOS `g7-asan` 绿、`g7-leak` 打 SKIP；Linux `g7-leak` 绿并把实测记录回填（`g7-lsan-record` 绿）。
- **前置**：PH-01、PH-02、PH-03。

## 3 未决项归属

| 未决项 | 归属 | 关闭方式 |
| --- | --- | --- |
| Q-2（`write_file` 失败半截） | PH-02 | 裁 D-006 后补 R-12 判据 |
| `FS_ERR_NOT_DIR` | PH-01 | 映射 `ENOTDIR` 或删除成员，二选一 |
| `ELOOP` | PH-02 | R-14 表加归类 + 环用例 |
| LSan 记录未回填 | PH-04 | **环境缺口已登记 `issues/FSG-03.md`**：本机无法启动 Linux 虚拟机（`podman machine start` / `krunkit` `VmCreate` 失败）。拿到任意 Linux 主机后跑 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`，把 host、命令与原始输出回填 `docs/reviews/fsguard-lsan-linux.md`；回填前 `g7-lsan-record` 判红 |
| R-01 判据 2/3（消费者 import） | PH-05（打包 1.1 已落地） | 上游已交付（PKG-2 已解决；本机 ct v0.58.0 实测 import 已解析）；打包 1.1 的 `publisher`/`ns-root` 已提交（`ct pkg check` 四条判据全过）。待建消费者夹具：只 `import fsguard::FsGuard`、不手写 import 根，C 头包含根用 `--cflags "-I<ns-root>"`，实际 build + 运行后接进门禁；`ct install` rc=0 不作为解析证明（PKG-6 open）。见 D-013 |
| R-02 判据 2（限定名取值） | PH-05 | 触发：`ct >= v0.59.0`（LANG-15 / PH-57 发布）后复跑 `FsErrCode::FS_ERR_*` 用例；未触发前不实施、不写跳过用例。见 D-013 |
| FSR-15（walk 根缺失） | PH-03 | 已收口：`g3-ph03 r07` 覆盖根不存在 → -1 + 冻结码、0 回调 |
| FSR-16（`normalize_to` 重叠） | PH-01 | 已收口：D-008 + `g3-ph01 r05` 的重叠拒绝用例 |

## 4 总退出

- 17 条 R 全部可验收，无「部分」状态。
- `bash tools/check.sh g0-decisions`、`g1-command`、`g4-static`、`g5-anchor`、`g6-contract`、`g7-asan` 全绿；Linux `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` 绿。
- 所有 D 裁定已落文件；无「待签」。
- 达到以上条件后允许建 phase 卡；**roadmap 已批准 PH-01 开工**，卡见 `docs/phases/PH-01/card.md`。本条此前写作「才允许建 phase 卡」，由本轮批准覆盖，其余条件不变。
