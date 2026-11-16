# CHANGELOG

本项目为 ct-fsguard（策略感知的文件系统层）。版本口径见 `AGENTS.md` 6.7：
MINOR 与 `PH-<n>` 收口同步，PATCH 与 fix 同步；tag 只标 phase。

## 0.5.0 — 2026-11-17（PH-05 收口三项挂起验收）

- R-01 判据 2/3：新增 `test/consumer/consumer.ct`，消费者只 import 本包单元，对 `char *` 调
  `normalize_to` / `is_under` / `read_chunk` / `walk` 并断言；`FsWalkCb` 具名回调实际被调用。
  门禁 `g3-ph05 consumer`，16 checks。
- R-02 判据 2：`r02_errors.ct` 补裸名/限定名 `FsErrCode::*` 双断言（11 条 qualified），
  `g3-ph01 r02` 22 checks；触发条件 `ct >= v0.59.0` 已满足（本机 v0.62.0）。
- R-17 判据 5：Linux（Debian 12 / aarch64 / gcc 12.2.0）实测
  `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` 输出
  `PASS: g7-leak: Linux ASan+LSan caught the leak`；记录回填 `docs/reviews/fsguard-lsan-linux.md`，
  `g7-lsan-record` 转绿（FSG-03 fixed）。
- 规划断尾修正：新建 `docs/phases/PH-05/card.md`；roadmap 增加 PH-05 并改 17/0；
  `AGENTS.md` 0.1 的版本/台账/门禁入口更新；验收命令去掉不存在的 `ct run`；
  打包计划标注 1.2 仍等上游、1.3 由 phase tag 覆盖。
- 门禁：`g1-phase-card` 支持 PH-05；`g4-static` 改 17/0；`all` 接入 `g3-ph05`；
  `g6-contract` 增加「PH-05 卡缺 `version-minor` 必红」负例。
- 已知：FSG-02（`ct install` 不识别 `.m.ct`）仍是上游 open，不阻塞 `ct build` + 运行验收。

## 0.4.0 — 2026-11-16（PH-04 包形态、平台与门禁）

- 包形态：`ct.pkg` 提交 `publisher = ct` 与 `ns-root = src`；`ct pkg check` 四条判据通过。
- 依赖：按 D-014 声明 `dep = std@0.3.2` 并提交 `ct.lock`；`vendor/` 不入库，包含根由共享包根提供。
  门禁口径为「声明了就必须可解析并记入 lock」。
- R-03 落地：`r03_coexist`（`std::fs` / `std::str` 与 `read_chunk` 在同一 `char *` 上并存）、
  `r03_qualified`（限定 `FsGuardOps::walk`）、`r03_ambiguous`（未限定 `walk` 必须歧义）进 `g3-ph04 r03`。
- R-15 平台边界：`a\b` 按字面字符处理，`src` 无 Win32 分支。
- R-16：README「能力对照表」与四个 `char *` 方法一一对应，不暴露 `exists`/`readFile`/`writeFile`/`list`。
- FSR-02/03 已知绕过负例（`r18_known_bypass`）与 FSR-04 手工清单进普通门禁。
- 包根清理：陈旧条目 `~/.ct/pkg/ct/std/0.3.1` 按 D-016 挪到 `~/.ct/pkg-backup/20261116/`，留可回退记录。
- 已知缺口：`ct install` 不识别 `.m.ct`（FSG-02，上游 `Pkg.h.ct:1609-1618`）；
  R-17 判据 5 的 Linux LSan 记录因本机无法启动 Linux 虚拟机而未产生（FSG-03）。

## 0.3.0 — 2026-11-15（PH-03 遍历与策略）

- `char *::walk` / `FsGuard::walk` 共用一份 walker，支持深度上限、回调中止与 deny 子树剪枝。
- `allow_prefix` / `deny_pattern` / `max_depth` 策略与 fail-closed 行为落地（D-004、D-005）。
- 借用失效（R-11）与遍历顺序不承诺的边界写进 README。

## 0.2.0 — 2026-11-15（PH-02 无状态原语、读写与错误面）

- `read_chunk`（offset 分块、二进制、EOF 语义）、`FsGuard` 生命周期与 `FsError` 契约。
- 读写走 `open` + errno 映射，错误码可分类（R-12、R-14；D-006、D-009）。
- 非法参数与 `ENOTDIR` / `ELOOP` 的错误码口径冻结。

## 0.1.0 — 2026-11-15（PH-01 路径词法与错误枚举）

- `normalize_to`、`is_under`、`check` 与 10 个 `FS_ERR_*` 错误码。
- `..` 钳制、段边界、deny 最小方言与词法策略层边界（D-002、D-003、D-012）。
- `pub trait` + `map trait` 包形态，`.h.ct` 回调，无 `#define` 宏面。
