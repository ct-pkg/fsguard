# ct-fsguard 需求盘点与评审状态核查

> 状态：只读盘点，基线 `16edb2f`（2026-11-15）。
> 范围：`docs/requirements.md`、`docs/proposal.md`、`docs/analysis.md`、`docs/design.md`、`README.md`、`AGENTS.md`、`docs/spec/ai-coding-workflow.md`、`git log` / `git status`。
> 纪律：未修改 `requirements.md` / `design.md` / `proposal.md`；仅新增本文件。

## 0 结论（可独立摘出）

需求文本共 **17 条**，其中 **12 条**判据可直接执行、**5 条**期望值仍挂在未决项上；缺口共 **16 项**（缺失 9、含糊 7）。结论：**文本够开展评审，不够开工**。仓库内没有任何两席评审、证据席或裁决记录，按 `AGENTS.md:51`（G1）与 `docs/spec/ai-coding-workflow.md:537-540`，需求未过评审不得进入实现。按阻塞程度排序，最多 5 条：

1. **评审未走**：无主张书、反证清单、`verdict.md`、`D-<n>`，无法取得 EDITOR 判决与签字，G1 与八环节第一道门就过不去。
2. **威胁模型未闭合**：TOCTOU、硬链接、挂载点/绑定挂载、超长路径、符号链接环五处未覆盖或未明文排除，包边界无法辩护。
3. **5 条判据期望值未冻结**：R-04/R-05/R-07/R-09/R-10 分别依赖 Q-5/Q-3/Q-4/Q-6/Q-7，同一输入存在多种"合法"期望值，写不出唯一断言。
4. **判据没有命令与阈值**：G1 要求"每条验收判据带可执行命令与通过阈值"（`AGENTS.md:51`），现有 17 条全是"运行 assert / 可核对"的描述；`tools/check.sh` 也未建（`AGENTS.md:266`），无法自证。
5. **错误面口径未统一**：fail-open / fail-closed 仅对"不可读子目录"一处定性（`requirements.md:228`），`write_file` 失败后是否留半截仍挂在 Q-2（`requirements.md:344`），部分成功无表达方式。

| 指标 | 值 |
| --- | --- |
| 需求条目 | 17（R-01 … R-17） |
| 可验收 / 含糊 / 不可 | 12 / 5 / 0 |
| 缺口项 | 16（缺失 9 / 含糊 7） |
| 评审状态 | **未经过两席评审** |
| 阻塞开工项 | 5 |

## 1 需求逐条梳理

`docs/requirements.md:11` 已自带 R-01…R-17 连续编号，本次无需自拟，逐条对应，未合并、未漏条。

| 编号 | 一句话内容 | 类型 | 可验收 | 来源锚点 |
| --- | --- | --- | --- | --- |
| R-01 | 包形态改为 `pub trait` + `map trait … for type char *`，方法体放 `.shim.h`，`FsWalkCb` 放 `.h.ct` | 非功能（形态/兼容） | 可 | proposal §2.1；analysis §2.1、§7.1–7.2 |
| R-02 | 10 个错误码改为 `pub enum FsErrCode`，名字与数值冻结、只追加 | 功能（接口常量） | 可 | proposal §2.3（原文）；analysis §2.3、§7.3 |
| R-03 | 四个新方法名与 `char *` 上已有 22 个 std 方法名不冲突，同文件混用无歧义 | 非功能（兼容） | 可 | proposal §2.1；analysis §2.7 |
| R-04 | `read_chunk` 按 offset 分块读，EOF 返回 0，二进制安全 | 功能 | 含糊（Q-5） | proposal §3.2；analysis §3.10、§7.11 |
| R-05 | `normalize_to` 只做词法规范化，不访问文件系统、不解析链接 | 功能 | 含糊（Q-3） | proposal §3.4；analysis §3.1、§3.13、§7.5 |
| R-06 | `is_under` 按路径段边界判定，`/src` 不误匹配 `/src2` | 功能 | 可 | proposal §3.1；analysis §3.7 |
| R-07 | `char *::walk` 增加 `max_depth` 与回调借用契约，深度可表达 | 功能 | 含糊（Q-4） | proposal §3.3、§3.5；analysis §3.5、§3.14、§7.9 |
| R-08 | `FsGuard` 显式 `impl Drop`、`new` 规范化存储、setter 返回同一指针 | 非功能（资源/所有权） | 可 | proposal §2.2、§4；analysis §2.5、§7.7 |
| R-09 | `check` 五步判定顺序冻结，root/allow 越界 `OUT_OF_BOUNDS`、deny 命中 `DENIED_PATTERN` | 功能 | 含糊（Q-6） | proposal §3.1；analysis §3.3–3.4、§7.4 |
| R-10 | 三个策略 setter 的覆盖语义、默认深度与 deny glob 最小方言 | 功能 | 含糊（Q-7） | proposal §2.2、§3.1；analysis §3.6、§7.10 |
| R-11 | `FsError` 只读借用、下次操作失效、`clear_error` 置 NULL、由 `FsGuard` 独占释放 | 功能 | 可 | proposal §2.3；analysis §3.2、§3.12、§7.8 |
| R-12 | `FsGuard` 的 `read_file`/`write_file`/`read_chunk` 包装与 errno 错误映射 | 功能 | 可 | proposal §2.2、§3.2；analysis §3.9–3.11、§7.11 |
| R-13 | `FsGuard::walk` 每个子项过策略，与 `char *::walk` 共用同一 walker | 功能 | 可 | proposal §3.3；analysis §3.5、§3.15、§7.9 |
| R-14 | 全包单一 `fsguard_errno_to_code`，包内 `fsguard_strdup`，偏移用 `long long`/`int64_t` | 功能（含可移植性） | 可 | proposal §2.3；analysis §2.8、§3.11、§7.12 |
| R-15 | MVP 仅 POSIX，不建 Win32 分支、不接受 `\` 分隔符 | 非功能（平台） | 可 | proposal §5、§9.5；analysis §5 |
| R-16 | 不替代也不修改 `std::fs`，不复制其方法名 | 非功能（边界/兼容） | 可 | proposal §1、§8；analysis §2.6 |
| R-17 | 夹具运行时生成、单一门禁覆盖全部断言、ASan/LSan 入闸 | 非功能（质量/验收） | 可 | proposal §6；analysis §4 |

说明：R-08/R-12 的剩余设计问题（Q-5/Q-2）只写在"设计缺口"，不改变其判据取值，故记"可"；R-17 的判据依赖尚未建立的 `tools/check.sh`（`AGENTS.md:266`），属实施前置，不影响判据本身可判定。

## 2 完整性评估

判定只用"有 / 缺失 / 含糊"。所有锚点为当前基线的 `file:line`。

### 2.1 目标与边界

| 检查点 | 判定 | 锚点与依据 |
| --- | --- | --- |
| 做什么（定位、能力表） | 有 | `docs/proposal.md:9-19`；`docs/requirements.md:31-40` |
| 明确不做什么 | 有 | `docs/proposal.md:21`；`docs/requirements.md:351-364`（8 类全局非目标） |
| 对外安全主张的边界 | 含糊 | `README.md:6` 已降级为"词法策略层"，但 Q-1 未确认（`docs/requirements.md:343`）；`docs/proposal.md:14`、`:19`、`:177` 仍保留"沙箱"表述 |

### 2.2 威胁模型

| 检查点 | 判定 | 锚点与依据 |
| --- | --- | --- |
| 路径穿越、`.`/`..` 归一化 | 有（规则待 Q-3） | `docs/requirements.md:86-110`、`:158-173`；Q-3 见 `:345` |
| 符号链接逃逸 | 有（明确排除） | `docs/requirements.md:297`（H-3）、`:358`；`README.md:6` |
| 大小写不敏感 | 有（明确不做） | `docs/requirements.md:121`、`:181`、`:258` |
| 权限不足 | 有 | `docs/requirements.md:213`（PERMISSION 映射）、`:228`（不可读目录 fail-closed） |
| TOCTOU 竞态 | 缺失 | 全文无该词；R-09 非目标只写"不 lstat/realpath/openat"（`:170`），不等于有 TOCTOU 口径 |
| 符号链接环 | 含糊 | 仅能从"不解析符号链接"（`:358`）推导；未明文写环 |
| 挂载点/绑定挂载 | 缺失 | 全文无 |
| 超长路径 / `PATH_MAX` | 缺失 | 全文无长度上限；R-04 `:80`、R-05 `:103` 均未定 |
| 硬链接 | 缺失 | 全文无 |

### 2.3 错误模型

| 检查点 | 判定 | 锚点与依据 |
| --- | --- | --- |
| 错误码与诊断形态 | 有 | `docs/requirements.md:46-50`（10 码）；`:192-199`（code/path/message、借用契约） |
| errno → 错误码映射 | 有 | `docs/requirements.md:241-245`（R-14 判据 1–2） |
| fail-open 还是 fail-closed | 含糊 | 仅 `:228` 对不可读子目录定 fail-closed；`walk` 的 `list` 失败、`read_file`/`write_file` 失败未统一 |
| 部分成功怎么表达 | 含糊 | `:344` Q-2 允许"失败可能留下部分内容"，但没有 API/返回值表达；R-12 判据 `:208-215` 未断言失败后文件状态 |

### 2.4 API 面

| 检查点 | 判定 | 锚点与依据 |
| --- | --- | --- |
| 函数签名 | 有（`walk` 待 Q-4） | `docs/proposal.md:29-86`；`docs/requirements.md:129` |
| 生命周期与所有权 | 有 | `docs/requirements.md:147-154`（Drop/delete）；`:192-199`（借用与失效） |
| 可重入 / 线程安全 | 含糊 | 仅 `:153` 写"不做线程安全"；两个 `FsGuard` 并发、`walk` 重入、`last_error` 共享均未定义 |
| 回调形态 | 有 | `docs/proposal.md:37`、`:153-159`；`docs/requirements.md:138` |

### 2.5 平台差异

| 检查点 | 判定 | 锚点与依据 |
| --- | --- | --- |
| 操作系统范围（POSIX） | 有 | `docs/requirements.md:251-260`（R-15） |
| macOS 与 Linux 路径语义、大小写、APFS 特性 | 缺失 | 只定"只接受 `/`"（`:256-258`）与"大小写敏感匹配"（`:181`）；未讨论 APFS 默认大小写不敏感卷、Unicode NFD/NFC |
| Win32 / 盘符 / `\` | 有（明确不做） | `docs/requirements.md:258`；`docs/proposal.md:181-185`（P2 分层） |

### 2.6 非功能

| 检查点 | 判定 | 锚点与依据 |
| --- | --- | --- |
| 深路径 / 树深度 | 有 | `docs/requirements.md:135`（20 层、`max_depth=16`）、`:179`（17 层） |
| 路径字符串长度上限 | 缺失 | 全文无；深树用例不等于长路径 |
| 大目录规模 | 缺失 | 全文无条目数/目录规模上限；R-13 只断言集合（`:224-229`） |
| 内存上限 | 缺失 | 全文无；`FS_ERR_OOM` 只是错误码，不是预算 |
| 性能目标 | 有（明确不做） | `docs/requirements.md:284`（R-17 非目标：不做性能基准） |

### 2.7 验收判据

| 检查点 | 判定 | 锚点与依据 |
| --- | --- | --- |
| 每条需求都有判据 | 有 | R-01…R-17 均含"验收判据"节，例 `:33`、`:74`、`:162` |
| 判据期望值唯一 | 含糊 | 5 条挂未决项：R-04←Q-5（`:78`）、R-05←Q-3（`:345`）、R-07←Q-4（`:346`）、R-09←Q-6（`:348`）、R-10←Q-7（`:349`） |
| 判据带命令与阈值（G1） | 缺失 | `AGENTS.md:51` 要求"每条验收判据有命令与阈值"；`docs/spec/ai-coding-workflow.md:286` 同；现有文本全是"运行 assert / 可核对" |
| 缺判据条目指名 | 有（0 条完全没有判据） | 受影响的是期望值唯一性，不是有无判据；上行列了 5 个编号 |

### 2.8 对 CT 语言能力的前置依赖

| 检查点 | 判定 | 锚点与依据 |
| --- | --- | --- |
| 依赖清单 | 有 | `docs/proposal.md:163-171`（L11/L5/L4/L8）；`docs/analysis.md:63-77` |
| 当前是否缺能力 | 有（0 硬阻塞、0 软阻塞） | `docs/requirements.md:15`、`:39`、`:52`、`:138`、`:154`、`:217`、`:259`；`docs/analysis.md:75-77` |
| 证据能否在本仓复核 | 含糊 | `docs/analysis.md:15-22` 的判据指向 `docs/language-spec.md:498-503` 等 ct-lang 路径，本仓无该仓与探针 |

### 2.9 缺口汇总

| 编号 | 缺口 | 判定 | 出处 |
| --- | --- | --- | --- |
| CG-01 | 对外"沙箱"主张未确认（Q-1） | 含糊 | 2.1 行 3 |
| CG-02 | TOCTOU 竞态 | 缺失 | 2.2 行 5 |
| CG-03 | 符号链接环 | 含糊 | 2.2 行 6 |
| CG-04 | 挂载点 / 绑定挂载 | 缺失 | 2.2 行 7 |
| CG-05 | 超长路径 / `PATH_MAX` | 缺失 | 2.2 行 8 |
| CG-06 | 硬链接 | 缺失 | 2.2 行 9 |
| CG-07 | fail-open / fail-closed 统一口径 | 含糊 | 2.3 行 3 |
| CG-08 | 部分成功表达 | 含糊 | 2.3 行 4 |
| CG-09 | 可重入性 | 含糊 | 2.4 行 3 |
| CG-10 | macOS/Linux 差异（APFS、Unicode） | 缺失 | 2.5 行 2 |
| CG-11 | 路径字符串长度上限 | 缺失 | 2.6 行 2 |
| CG-12 | 大目录规模 | 缺失 | 2.6 行 3 |
| CG-13 | 内存上限 | 缺失 | 2.6 行 4 |
| CG-14 | 判据无命令与阈值（G1） | 缺失 | 2.7 行 3 |
| CG-15 | 5 条判据期望值待冻结 | 含糊 | 2.7 行 2 |
| CG-16 | 语言能力证据不可本仓复核 | 含糊 | 2.8 行 3 |

合计 16 项：缺失 9（CG-02/04/05/06/10/11/12/13/14），含糊 7（CG-01/03/07/08/09/15/16）。

## 3 评审状态核查

### 3.1 文档证据

| 应有记录 | 实际 | 锚点 |
| --- | --- | --- |
| 主张席（主张书） | 无 | `docs/` 仅 6 个文件；无 `battle/`、无 `claim.md` |
| 反证席（反证清单） | 无 | 无 `counter.md`、无 `docs/reviews/*` 评审报告 |
| 证据席（可复现证据） | 无 | 无 `verify.json`、无门禁脚本 |
| 裁判席（裁决记录） | 无 | 无 `docs/decisions/`；`AGENTS.md:269` 自述"决策记录 未建" |
| Issue 台账 | 无 | `issues/` 不存在；`AGENTS.md:268`"Issue 台账 未建" |
| 门禁 | 无 | `tools/check.sh` 不存在；`AGENTS.md:266`"门禁入口 未建" |
| 会话映射 | 空表 | `docs/session-map.md:3-4` 只有表头 |
| 提案 §9 的 5 个问题 | 未答 | `docs/proposal.md:250-256`；`docs/requirements.md:341-349` 仍是 Q-1…Q-7"待确认" |

### 3.2 git 证据

- `git log --oneline` 仅两个提交：`16edb2f docs: 补需求层梳理…`、`71bde35 docs: 文档先落库`；无评审、签字、裁决类提交。
- `git status --short` 输出 `?? AGENTS.md`、`?? docs/spec/`：规范生成块与全文副本尚未入库，G0 本身无法通过（`AGENTS.md:50`）。

### 3.3 结论

**未经过两席评审。** `docs/analysis.md:3` 自述为"只读评估"，是单方意见，不构成反证席；`docs/requirements.md` 是单方需求梳理，不构成主张书；仓库内没有证据席、没有裁判判决、没有 `D-<n>` 决策记录。提案 §9 的五个问题至今没有评审线答复。

### 3.4 按工程规范应走的步骤

| 步 | 谁 | 产物 | 判据/锚点 |
| --- | --- | --- | --- |
| 出需求条目 | REQ | `docs/requirements.md`（含命令与阈值） | `docs/spec/ai-coding-workflow.md:283-286`；`AGENTS.md:51` |
| 出 phase 卡 | EDITOR | `docs/phases/PH-<n>/card.md` | `docs/spec/ai-coding-workflow.md:273-274` |
| 立案 | 发起方 + EDITOR 确认 | `battle/<id>/question.md`：争点、逐条判据、`proposer`/`opposition`/`judge` | `docs/spec/ai-coding-workflow.md:836`、`:845` |
| 反证 | 需求类 REVIEW；安全面 APPSEC；可行性 ARCH | `counter.md`：逐条失效条件 | `docs/spec/ai-coding-workflow.md:792-796`；H-1 `:804` |
| 出证 | VERIFY（构建/依赖时 ARCH 合署） | `verify.json`：命令 + 输出 + 环境（E1–E5） | `docs/spec/ai-coding-workflow.md:816`、`:824-830` |
| 裁决 | EDITOR（唯一裁判，不表态不投票，≤3 轮） | `verdict.md`：逐条判据成立/不成立 + 生效范围 | `docs/spec/ai-coding-workflow.md:784`、`:807`、`:849-860` |
| 落盘签字 | REQ 写争点与主张段，EDITOR 写判决段 | `docs/decisions/D-<n>.md`（13 个字段） | `docs/spec/ai-coding-workflow.md:76`、`:430`、`:841-842` |
| 立项前置 | REQ | `docs/planning/analysis/AN-<id>.md`（问题、范围、判据、依赖风险四段） | `docs/spec/ai-coding-workflow.md:481` |
| 归档 | 调度 | `battle/<id>/closed.md`，关联 Issue 离开 `open` | `docs/spec/ai-coding-workflow.md:843` |

签字口径：判决必须逐条判据给结论并写明生效范围（`:859`）；用户只在两种情形出场——无判据需价值判断、三轮仍无结论（`:817`）；主张人不得担任裁判（`:805`）。本项目的评审对阵应按"做什么、为什么"一行走：主张 REQ、反对 REVIEW、证据 ARCH（`:792`）；涉及安全边界（符号链接、越界、fail-open）时反对席换 APPSEC（`:796`）。

## 4 结论（展开）

### 4.1 够不够开工

**不够。** 需求已从提案拆成 17 条可讨论、可判定的条目，结构上达到"可评审"水平；但 G1 的两项硬要求（判据带命令与阈值、无 TBD）均未满足，且两席评审与裁决完全缺位，按 `AGENTS.md:51` 与八环节（`docs/spec/ai-coding-workflow.md:537-540`）不能进入实现。

### 4.2 阻塞项（按阻塞程度，5 条）

| 序 | 阻塞项 | 为什么卡 |
| --- | --- | --- |
| 1 | 两席评审与裁决缺位 | 没有 `question.md`/`counter.md`/`verify.json`/`verdict.md`/`D-<n>`，无法取得 EDITOR 判决与签字；G1、G6 都过不去 |
| 2 | 威胁模型 5 处未闭合（CG-02/04/05/06 + CG-03） | TOCTOU、硬链接、挂载点、超长路径、链接环不写清，安全面无法判定"边界是否成立"，APPSEC 反证必然打回 |
| 3 | 5 条判据期望值未冻结（CG-15） | R-04/R-05/R-07/R-09/R-10 的期望值取决于 Q-5/Q-3/Q-4/Q-6/Q-7，同一输入多种合法答案，DEV 无法先红后绿 |
| 4 | 判据无命令与阈值、门禁未建（CG-14） | G1 机械判据不满足；没有 `tools/check.sh` 就无法按 G5 自证"负例曾变红" |
| 5 | 错误面口径未统一（CG-07/08） | 只有一处 fail-closed；`write_file` 失败留不留半截挂 Q-2，失败路径行为不可测、不可回归 |

### 4.3 不阻塞但需补齐（其余 11 项）

CG-01（Q-1 对外表述）、CG-09（可重入）、CG-10（macOS/APFS 与 Unicode）、CG-11/CG-12/CG-13（长度、规模、内存）、CG-16（语言证据外仓复核）可在 G0/立项卡前补齐；CG-03 可随符号链接策略一并写明"不解析即无环风险"。这些不单独阻断评审，但需在 phase 卡的退出判据里有落点。

### 4.4 给决策者的一句话

先按 §3.4 补齐两席评审与 `D-<n>`，同时把 5 条判据的期望值冻结、把缺口 16 项分派到 G0b 与 phase 卡；在没有 EDITOR 判决之前，这份需求只能算"可评审的草案"，不能算"可开工的规格"。
