# ct-fsguard roadmap（PH-01…PH-05 已收口）

> 状态：PH-01…PH-05 已收口；17 条 R 全部有结论，roadmap 不再有未完成 phase。
> 本文件只排相与退出概要，**不建 phase 卡、不改代码**；卡见 `docs/phases/PH-<n>/card.md`。

## 0 结论

需求已可进入 roadmap 与 phase 规划。PH-01…PH-04 覆盖 14 条完整可验收 + 3 条部分（R-01 判据 2/3、R-02 判据 2、R-17 判据 5）；**PH-05 收口这三条后为 17 条可验收、0 条部分可验收**。规划复核见 `docs/reviews/fsguard-phase-plan-review.md`。

## 1 相划分

| 相 | 目标 | 覆盖 R | 前置相 | 退出判据概要 |
| --- | --- | --- | --- | --- |
| PH-01 | 路径词法与错误枚举 | R-02、R-05、R-06、R-09 | 无 | 九行规范化表、绝对段边界、check 顺序与码、10 码枚举冻结 |
| PH-02 | 无状态原语、读写与错误面 | R-04、R-08、R-11、R-12、R-14 | PH-01 | offset/EOF/二进制、生命周期、FsError 契约、读写边界、errno 映射 |
| PH-03 | 遍历与策略 | R-07、R-10、R-13 | PH-02 | 三参数 walk/深度/借用、deny 最小方言、deny 子树与 fail-closed |
| PH-04 | 包形态、平台与门禁 | R-01、R-03、R-15、R-16、R-17 | PH-01…PH-03 | 包形态/命名共存、POSIX 边界、std::fs 零改动、夹具与平台化门禁 |
| PH-05 | 收口三项挂起验收（已收口） | R-01 判据 2/3、R-02 判据 2、R-17 判据 5 | PH-04；`ct >= v0.59.0`；Linux 主机 | 消费者夹具、限定名断言、Linux LSan 记录 |

覆盖核对：PH-01…PH-04 覆盖 17 条 R 的主体（4 + 5 + 3 + 5），其中 R-01/R-02/R-17 的三条判据按 D-013 与 PH-04 收口记录移出/挂起，由 PH-05 收口；不是第二轮重复归属，也不留未归属项。PH-05 的退出判据逐条对应这三条判据，不新增功能。

## 2 各相说明

### PH-01 路径词法与错误枚举（已收口）

- **目标**：先把 `normalize_to`、`is_under`、`check` 与 `FsErrCode` 冻结成可判定的词法核心。
- **覆盖**：R-02、R-05、R-06、R-09。
- **退出判据概要**：
  - R-05 九行表逐行 assert；`cap` 边界与 `out[0]==0`。
  - R-06 只用绝对路径做段边界（D-002）；R-09 顺序与错误码冻结。
  - R-02 十码冻结；`FS_ERR_NOT_DIR` 在「映射到 `ENOTDIR`」或「删除成员」中二选一并补判据。
  - 新增 R-05 的 `out`/`path` 重叠检测（FSR-16），不能只靠 README 禁止。
- **前置**：D-001、D-002、D-003 已裁；roadmap 批准。

### PH-02 无状态原语、读写与错误面（已收口）

- **目标**：落 `read_chunk` 与 `FsGuard` 的 `read_file` / `write_file`，把 errno 映射和生命周期收口。
- **覆盖**：R-04、R-08、R-11、R-12、R-14。
- **退出判据概要**：
  - R-04 offset/EOF/负值/二进制/NUL 用例；公开偏移为 `long long`/`int64_t`。
  - R-08 工厂/`delete`/setter 链式/非法参数；ASan 下无重复释放。
  - R-11 借用失效、`clear_error`、`check` 失败置错；LSan（Linux）无泄漏。
  - R-12 读写边界、越界不落 I/O；Q-2 裁定后补失败后文件状态断言。
  - R-14 四类 errno 映射；补 `ELOOP` 归类与环用例。
- **前置**：PH-01；Q-2 必须在 R-12 退出前裁定。

### PH-03 遍历与策略（已收口）

- **目标**：落 `char *::walk` 与 `FsGuard::walk`，把深度、deny 与 fail-closed 写死。
- **覆盖**：R-07、R-10、R-13。
- **退出判据概要**：
  - R-07 三参数签名（D-004）、`max_depth=0/1/16`、回调中断、借用契约。
  - R-10 默认深度 16、覆盖语义、deny 最小方言（D-005）、空串未配置。
  - R-13 root 回调、deny 子树 0 回调、不可读子目录 fail-closed、共用 walker。
  - 补 FSR-15：walk 根不存在 → -1 + 冻结码、0 回调。
- **前置**：PH-02；D-004、D-005 已裁。

### PH-04 包形态、平台与门禁（已收口）

- **目标**：把包形态、命名共存、POSIX 边界与门禁收口，形成可交付包。
- **覆盖**：R-01、R-03、R-15、R-16、R-17。
- **退出判据概要**：
  - R-01 `pub trait` + `map trait` + `.h.ct` 回调；包内 `#define` 计数 0。
  - R-03 四个方法名与 22 个 std 名字无交集；判据 1/2/3 由 `g3-ph04 r03` 的三个用例覆盖（共存、限定调用、未限定调用必须歧义）。
  - R-15 只接受 `/`；`a\b` 字面处理；无 Win32 分支。
  - R-16 `std::fs` 零改动；不暴露同名方法。
  - R-17 夹具运行时生成、入门禁；macOS `g7-asan` 绿、`g7-leak` 打 SKIP；Linux `g7-leak` 绿并把实测记录回填（`g7-lsan-record` 绿）。
- **前置**：PH-01、PH-02、PH-03。

### PH-05 收口三项挂起验收（已收口）

- **目标**：把 PH-04 移出/挂起的三条判据收成运行证据，使 17 条 R 全部有结论。
- **覆盖**：R-01 判据 2/3、R-02 判据 2、R-17 判据 5。
- **退出判据概要**：
  - R-01 判据 2/3：消费者只 import 本包单元，四方法 + `FsWalkCb` 实际调用；`g3-ph05 consumer` 绿。
  - R-02 判据 2：裸名与限定名分别 assert；`g3-ph01 r02` 绿，输出含 `qualified`。
  - R-17 判据 5：Linux LSan 记录；`g7-lsan-record` 绿。
  - 收口：`all` 绿、版本 0.5.0、CHANGELOG、annotated tag `v0.5.0`。
- **前置**：PH-04；`ct >= v0.59.0`（本机 v0.62.0）；Linux 主机（Lima Debian 12）。
- **边界**：不改判据原文、不改实现行为、不处理 FSG-02 上游缺陷、不迁移规范 pin。

## 3 未决项归属

| 未决项 | 归属 | 关闭方式 |
| --- | --- | --- |
| Q-2（`write_file` 失败半截） | PH-02 | 已裁 D-006 并补 R-12 判据 |
| `FS_ERR_NOT_DIR` | PH-01 | 已收口：D-009 映射 `ENOTDIR → NOT_DIR` |
| `ELOOP` | PH-02 | 已收口：D-009 归 `FS_ERR_IO`，`r14` 有环用例 |
| LSan 记录未回填 | PH-05 | 已登记 `issues/FSG-03.md`；PH-05 在 Linux 主机上跑 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`，按模板回填 `docs/reviews/fsguard-lsan-linux.md` 后 `g7-lsan-record` 转绿 |
| R-01 判据 2/3（消费者 import） | PH-05 | 打包 1.1 已提交 `publisher`/`ns-root`；PH-05 建消费者夹具，实际 build + 运行后接 `g3-ph05`；`ct install` rc=0 不作为解析证明（PKG-6 open、FSG-02 open） |
| R-02 判据 2（限定名取值） | PH-05 | 触发条件 `ct >= v0.59.0` 已满足（本机 v0.62.0）；PH-05 复跑 `FsErrCode::FS_ERR_*` 用例；未触发前不实施、不写跳过用例。见 D-013 |
| FSR-15（walk 根缺失） | PH-03 | 已收口：`g3-ph03 r07` 覆盖根不存在 → -1 + 冻结码、0 回调 |
| FSR-16（`normalize_to` 重叠） | PH-01 | 已收口：D-008 + `g3-ph01 r05` 的重叠拒绝用例 |

## 4 总退出

- 17 条 R 全部可验收，无「部分」状态。
- `bash tools/check.sh g0-decisions`、`g1-command`、`g1-phase-card`、`g4-static`、`g5-anchor`、`g6-contract`、`g7-asan`、`g7-leak`、`g7-lsan-record` 全绿；Linux LSan 记录已回填。
- 所有 D 裁定已落文件；无「待签」。
- 达到以上条件后允许建新的 phase 卡；PH-05 收口后 roadmap 不再有未完成 phase。
