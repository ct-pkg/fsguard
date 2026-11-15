# ct-fsguard 反证席报告

> 对象：`docs/requirements.md`（R-01…R-17）+ `docs/design.md`；基线 `4a6a679`。
> 立场：反证方。只找会导致返工、错误实现或无法验收的地方，不复述需求。
> 证据约定：`[实测 E#]` 见 §6 的命令与原始输出；`[未实测]` 表示仓库无实现，只能由签名或文本推出，已明确标注。

## 0 评审结论（按 8.2 最小结构）

- **结论：不通过。**
- **分级**：P0 8 条、P1 9 条、P2 1 条；条目号 FSR-01…FSR-18。
- **覆盖范围**：`requirements.md` 全 17 条、`design.md` 全 12 条、`proposal.md` §1–§9、`analysis.md` §2–§7；`git log` 与评审产物目录。
- **未覆盖声明**：未编译 ct-lang 探针（语言形态引用 `analysis.md`）；未创建挂载点（需特权）；所有包内行为均未实测（仓库无实现）。
- **主张一致性**：17 条 R 全部没有可执行门禁命令（FSR-08）；5 条判据的期望值挂在 Q-3…Q-7（FSR-07）。
- **文档时效**：`stale_docs` 按提交计为 0（proposal/analysis/design 自 `71bde35` 未改，requirements 自 `16edb2f` 未改，无发布周期）；`unverified_claims` 17；`docs_without_gate` 9（`docs/` 与根级非规范副本文档，不含本文件）。
- **安全**：威胁模型五处中，TOCTOU、硬链接、挂载点/绑定为 P0；超长路径、符号链接环为 P1（FSR-02…06）。

## 1 上一轮 5 条阻塞项的落点

| 盘点阻塞项 | 本文件条目 | 导致无法验收的提案原句 |
| --- | --- | --- |
| 评审缺位 | FSR-01 | `proposal.md:250`「## 9 需评审线确认」；五问至今无答复 |
| 威胁模型五处未闭合 | FSR-02…06 | `requirements.md:170`「不做真沙箱（不 lstat、不 realpath、不 openat）」 |
| R-04/05/07/09/10 依赖 Q-3…Q-7 | FSR-07 | `requirements.md:339`「未确认前按建议口径写判据」 |
| 判据无命令与阈值 | FSR-08、FSR-17 | `requirements.md:281`「一条门禁命令覆盖…」但无命令名；LSan 在 macOS 不可用 |
| fail-open/closed 与部分成功不统一 | FSR-09 | `proposal.md:144`「越界子项跳过（不中断）」vs `requirements.md:228` fail-closed 中断 |

## 2 详细反对条目

### FSR-01 评审缺位（P0）

- **主张原文**：`docs/proposal.md:250`「## 9 需评审线确认」；`:252`「1. FsGuard * 上的方法与 char * 宿主方法是否零冲突？…请确认。」
- **反驳**：五个问题写给"评审线"，但仓库没有任何答复、反证或裁决；`requirements.md:339` 又规定"提案方确认或否决后只改对应一条"，等于把验收挂在一个未发生的外部动作上。`requirements.md:3` 自述"未立项"。
- **依据**：[实测 E1] `battle`、`docs/decisions`、`issues` 均不存在，`git log` 只有 5 个 `docs:` 提交。
- **严重度**：阻断（P0）
- **最小改法**：按规范 §7 走 T0–T7，产出 `question.md`/`counter.md`/`verify.json`/`verdict.md` 与 `D-<n>`；至少先对 Q-1…Q-7 留下提案方书面裁定。

### FSR-02 TOCTOU 无防护、无判据（P0）

- **主张原文**：`requirements.md:170`「不做真沙箱（不 `lstat`、不 `realpath`、不 `openat`）；不访问文件系统」；`:214`「越界时先 `check` 后调原语」。
- **反驳**：`check` 是词法判定，与实际 `open` 分离；两者之间路径可被替换为链接。API 不返回 fd、不提供 `openat(O_NOFOLLOW)`，调用方无法自行闭合这个窗口；判据里也没有任何竞态用例。
- **依据**：[实测 E3] 根内 `evil` 指向根外文件，`cat` 打印 `OUTSIDE`，rc=0；`[未实测]` 包内 `read_file` 按 `analysis.md:35` 预期同样越界，仓库无实现可跑。
- **严重度**：阻断（P0）
- **最小改法**：要么把 TOCTOU 写成显式非目标并补"承认绕过"的负例；要么改 API 为 `openat`/fd 形态。现有签名做不到防护。

### FSR-03 硬链接无防护（P0）

- **主张原文**：`requirements.md:121`「不做大小写不敏感比较；不做 inode/真实路径比较」；`proposal.md:14`「路径处理 … 沙箱校验」。
- **反驳**：根内硬链接指向根外 inode，词法路径完全在根下，`check` 必然放行；不比较 inode/nlink 就无法区分。`proposal.md:14`、`:19`、`:177` 仍称"沙箱"，与"不做 inode 比较"直接冲突。
- **依据**：[实测 E4] 根外文件与根内链接 `inode` 同为 `11889029`、`nlink=2`，`cat` 打印 `HARD`，rc=0；`[未实测]` 包内行为。
- **严重度**：阻断（P0）
- **最小改法**：删除"沙箱"表述并把硬链接列为非目标 + 负例；或新增 `lstat` `nlink>1` 拒绝（同时修改 `:121` 的非目标）。

### FSR-04 挂载点/绑定挂载无防护（P0）

- **主张原文**：`requirements.md:170`「不做真沙箱…不访问文件系统」；`proposal.md:177`「路径规范化、沙箱检查、遍历都是词法操作」。
- **反驳**：绑定挂载可以让根外目录以根内路径出现；词法检查只看字符串，`st_dev`/挂载表都不看。全文没有"挂载点"三个字，也没有对应判据。
- **依据**：[未实测] 创建挂载需要 root，普通 CI 不能跑；现有 API 也没有 `st_dev` 面。结论是"现有 API 形态下无法判定/防护"，不是"需要注意"。
- **严重度**：阻断（P0，若 Q-1 改为"词法策略层"可降 P1）
- **最小改法**：明确写"挂载点/绑定挂载不在防护范围"并给出不可自动化的理由；若要防护，需新增 `st_dev` 比较面。

### FSR-05 超长路径无上限（P1）

- **主张原文**：`requirements.md:103`「`out` 容量不足时返回 -1 且 `out[0] == 0`…`cap == len+1` 时成功」——只定义输出容量，没有输入长度。
- **反驳**：`path` 没有长度上限；`check` 可能对超长路径返回 `FS_OK`，真正 `open` 时 `ENAMETOOLONG` 落到 R-14 的"其余 → IO"，调用方无法区分"路径太长"与"磁盘错误"。没有判据。
- **依据**：[实测 E6] `getconf PATH_MAX /` → `1024`，rc=0；5000 字符路径 `errno=63 File name too long`。`[未实测]` 包内映射。
- **严重度**：需改（P1）
- **最小改法**：定一个输入上限（如 `PATH_MAX`）并在 `check` 阶段返回显式错误；或明文规定 `ENAMETOOLONG→FS_ERR_IO` 并补用例。

### FSR-06 符号链接环未定义（P1）

- **主张原文**：`proposal.md:149`「不解析符号链接」；`requirements.md:358` 把符号链接解析列为全局非目标；`:242`「其余 → `IO`」。
- **反驳**：`a→b→a` 的环在词法检查中完全合法；`open` 返回 `ELOOP`，而 R-14 的映射表没有 `ELOOP`，只能落到 `FS_ERR_IO`。没有任何判据说这是预期行为。
- **依据**：[实测 E5] `cat` 输出 `Too many levels of symbolic links`，rc=1；`[未实测]` 包内 `ELOOP→IO` 只能由映射表推出。
- **严重度**：需改（P1）
- **最小改法**：在 R-14 表中显式写 `ELOOP` 的归类（建议 `FS_ERR_IO` + message），并补一条环用例；或明确"环不在范围"。

### FSR-07 Q-3…Q-7 未裁导致 5 条判据不可冻结（P0）

- **主张原文**：`requirements.md:339`「以下 7 条每条已给建议口径，未确认前按建议口径写判据；提案方确认或否决后只改对应一条。」
- **反驳**：这不是冻结，是"先按建议写、以后可能改"。5 条判据直接依赖未决项：R-05 表（`:109`←Q-3）、R-07 判据 3（`:133`←Q-4）、R-04 判据 4（`:78`←Q-5）、R-09 判据 7（`:169`←Q-6）、R-10 判据 3（`:181`←Q-7）。Q-5 还影响 R-08 setter 与 R-10 判据 5。
- **依据**：[实测 E2/E10] 五处依赖在文本中可逐行定位；`待确认` 出现 6 行，`TBD` 0 行；无任何裁决文件。
- **严重度**：阻断（P0）
- **最小改法**：把 Q-3…Q-7 逐条转成 `D-<n>` 决策（选项见 §3），再只改受影响的那一条判据并冻结。

### FSR-08 判据没有命令与阈值（P0）

- **主张原文**：`requirements.md:281`「一条门禁命令覆盖 R-01…R-16 的全部运行断言；失败时输出失败用例编号」；`AGENTS.md:51` 要求"每条验收判据有命令与阈值"。
- **反驳**：全文没有一个以 `$ ` 开头的命令块；`tools/check.sh` 不存在。R-01 判据 1 只写"grep 命中数 = 0"，没给 grep 目标和命令；R-17 判据 3 说"一条门禁命令"，但没有命令名。G1/G5 都无法执行。
- **依据**：[实测 E9] `ls -d tools` → `No such file or directory`，rc=1；`grep -c '^\$ ' requirements.md` → 0。
- **严重度**：阻断（P0）
- **最小改法**：为每条判据补"命令 + 期望退出码/输出"，或先落 `tools/check.sh <case-id>` 并让 R-17 引用它；没有命令的判据不算判据。

### FSR-09 fail-open/closed 与部分成功口径冲突（P0）

- **主张原文**：`proposal.md:144`「每个子项回调前 check，越界子项跳过（不中断）」；`requirements.md:228`「不可读子目录…按 fail-closed 处理：中断并返回 -1 + `FS_ERR_PERMISSION`」；`:344` Q-2「失败可能留下部分内容」。
- **反驳**：同一套遍历里，越界子项"跳过继续"，不可读子目录"中断"，但没有规则区分哪些失败可跳、哪些必须停。`write_file` 允许留半截，却没有返回值/API 表达部分成功；`walk` 的 `list` 失败（ENOENT/EIO）也没有归类。
- **依据**：[实测 E2] 文本可逐行对照；`[未实测]` 行为无实现。
- **严重度**：阻断（P0）
- **最小改法**：冻结一张失败矩阵：失败类别 → 跳过/中断、返回码、是否置 `last_error`、是否允许副作用；每行一条判据，并先裁 Q-2。

### FSR-10 `is_under` 相对路径示例与段边界定义冲突（P1）

- **主张原文**：`requirements.md:114`「字符串前缀会把 `/workspace/src2` 误判为 `/workspace/src` 之下」；`:116`「`src/a.c` vs `/workspace/src` → 1」。
- **反驳**：按"路径段边界"直接比较，`src/a.c` 与 `/workspace/src` 没有任何公共前缀，结果必然是 0；要得到 1，必须先定义相对路径如何锚定到绝对前缀——这正是 Q-6 未定的内容。判据按字面实现会自相矛盾。
- **依据**：[实测 E7] 段边界探针输出 `'src/a.c' vs '/workspace/src' -> 0`、`'src2/a.c' -> 0`、`'/workspace/src/a.c' -> 1`，rc=0；`[未实测]` 包内行为。
- **严重度**：需改（P1）
- **最小改法**：把示例改成 `/workspace/src/a.c`→1；或先裁 Q-6 并在 R-06 写明相对路径的锚定规则。

### FSR-11 `new` 失败没有错误通道（P1）

- **主张原文**：`proposal.md:72`「`static FsGuard *new(char *root);`」；`requirements.md:149-152` 只定义 `new` 的根行为与 setter 非法参数。
- **反驳**：`new` 分配失败时返回什么、`FS_ERR_OOM` 怎么被调用方看到，均未定义。没有对象就没有 `last_error()`，用户只能看到 `NULL`，无法区分 OOM 与非法 root。
- **依据**：[未实测] 无实现；由签名与 `last_error` 契约推出。
- **严重度**：需改（P1）
- **最小改法**：冻结 `new` 失败语义（建议返回 NULL + 一个可查询的静态错误，或新增 `FsGuard::new_ex`），并补一条判据。

### FSR-12 `write_file` 成功返回值未定义（P1）

- **主张原文**：`proposal.md:79`「`int write_file(char *path, char *data, int len);`」；`requirements.md:211-212` 只断言失败 -1 与越界不创建。
- **反驳**：成功时返回 `len`、0 还是实际写入字节数没有规定；`requirements.md:216` 又明确"不做部分写重试"，因此也不存在"部分写"返回值。调用方无法写成功断言。
- **依据**：[未实测] 无实现；由签名与判据推出。
- **严重度**：需改（P1）
- **最小改法**：冻结成功返回 `len`（或 0），并在 R-12 增加一条成功返回值判据。

### FSR-13 `FS_ERR_NOT_DIR` 是死代码（P1）

- **主张原文**：`requirements.md:46` 定义 `FS_ERR_NOT_DIR = 6`；`:242` 又把 `ENOTDIR` 映射到 `NOT_FOUND`。
- **反驳**：全包只有定义处出现 `NOT_DIR`；错误映射把唯一可能产生它的 `ENOTDIR` 送给了 `NOT_FOUND`。这是对外承诺了一个永远不会出现的码，调用方会写无效分支。
- **依据**：[实测 E10] `FS_ERR_NOT_DIR` 仅出现在 `proposal.md:106` 与 `requirements.md:46`。
- **严重度**：需改（P1）
- **最小改法**：要么把 `ENOTDIR→FS_ERR_NOT_DIR` 并补判据，要么删掉该成员（会破坏"10 码冻结"，需 Q-5 一并裁）。

### FSR-14 `read_chunk` 的 `len<=0` 没有判据（P1）

- **主张原文**：`requirements.md:76-77` 判据覆盖 offset/EOF，没有 `len` 边界；`requirements.md:347` Q-5 才写「`len<0` 返回 -1 + `FS_ERR_IO`，`len==0` 返回 0」。
- **反驳**：Q-5 是建议不是判据；R-04 本身没有 `len==0`/`len<0` 的断言。调用方传 0 或负数时，实现可以返回 0、-1 或崩溃而不违反现有判据。`buf == NULL` 与 `len==0` 的组合也未定。
- **依据**：[未实测] 无实现；文本可核对。
- **严重度**：需改（P1）
- **最小改法**：在 R-04 增加 `len==0→0`、`len<0→-1 + 冻结码` 两条判据，并先裁 Q-5。

### FSR-15 `walk` 根不存在时行为未定义（P1）

- **主张原文**：`requirements.md:226` 只写「root 越界返回 -1」；`:228` 写不可读子目录 fail-closed；`proposal.md:141` 写「包含 root 本身」。
- **反驳**：root 不存在时，`check` 是纯词法会返回 `FS_OK`，失败只会在 `list/opendir` 出现；返回 `NOT_FOUND`、`IO` 还是 0 次回调成功，三者都没定义。
- **依据**：[未实测] 无实现；由 `check` 纯词法（`:166`）与 `walk` 判据推出。
- **严重度**：需改（P1）
- **最小改法**：补一条判据：root 不存在 → -1 + `FS_ERR_NOT_FOUND`，回调次数 0（或裁定其他形态）。

### FSR-16 `normalize_to` 重叠缓冲区靠文档禁止（P1）

- **主张原文**：`requirements.md:106`「`out` 与输入重叠（`out == path`）被文档禁止，README 写明该限制（可核对）；实现不负责检测。」
- **反驳**：公开 API 接受两个 `char *`，用户传同一缓冲区是常见错误；"README 禁止 + 实现不检测"意味着 UB 留在调用点。判据还把它写成"可核对"的文档项，不是行为项。
- **依据**：[未实测] 无实现；按 C 语义，重叠读写无保证。
- **严重度**：需改（P1）
- **最小改法**：`out == path` 或区间重叠时返回 -1；或把签名改成 `const char *path` + 独立 `out` 并在判据中测重叠。

### FSR-17 LSan 在 macOS 不可用（P0）

- **主张原文**：`requirements.md:283`「ASan/LSan 作为门禁一环，覆盖 R-08、R-11、R-13 的所有权用例。」
- **反驳**：本机 macOS 的 ASan 明确不支持 `detect_leaks`，该门禁在本机无法按字面执行；如果 CI 只在 Linux 跑，判据必须写明平台，否则 macOS 开发者无法自证所有权。
- **依据**：[实测 E8] `cc -fsanitize=address` rc=0；`ASAN_OPTIONS=detect_leaks=1` 运行输出 `AddressSanitizer: detect_leaks is not supported on this platform.`，rc=134。
- **严重度**：阻断（P0；若判据限定 Linux 可降 P1）
- **最小改法**：按平台拆分：Linux 跑 ASan+LSan；macOS 跑 ASan + `leaks`/`valgrind`，或登记 `deviation:` 并写清覆盖缺口。

### FSR-18 `FS_ERR_OOM` 不可运行时验收（P2）

- **主张原文**：`requirements.md:243`「`FS_ERR_OOM` 只在 `malloc` / `fsguard_strdup` 失败时使用（可核对）。」
- **反驳**："可核对"是代码检查，不是运行判据；没有分配失败注入点，也没有门禁用例。检查可以被"写了分支但从不触发"满足。
- **依据**：[未实测] 无实现。
- **严重度**：仅澄清（P2）
- **最小改法**：加分配器注入钩子并补一条 OOM 用例；或把它降为代码评审清单项，不计入 G5。

## 3 威胁模型五处：可自动化判据或明确无法判定
| 威胁 | 可自动化判据（实现后） | 现有 API 能否判定 |
| --- | --- | --- |
| TOCTOU | 根内文件 → `check` OK → 替换为根外链接 → `read_file`，断言读到根外内容；该测试证明的是"绕过成立"，不是"防护成立" | 不能防护；只能证明失败 |
| 硬链接 | 根外文件 `ln` 到根内 → `check` OK → `read`，断言读到根外内容 | 不能，除非新增 nlink/inode 面 |
| 挂载点/绑定 | 需 root 创建 bind mount，非普通 CI 可跑；`check` 仍 OK | 不能；且无法自动入门禁 |
| 超长路径 | 生成长度 > `PATH_MAX` 的路径 → `check` 与 `read`，断言冻结的错误码 | 能判定，但错误码未冻结（FSR-05） |
| 符号链接环 | `a→b→a` → `check` OK → `read`，断言 -1 + 冻结码 | 能判定，但 `ELOOP` 归类未冻结（FSR-06） |

## 4 Q-3…Q-7：可裁选项与代价
### Q-3 `..` 消解
| 选项 | 做法 | 代价 |
| --- | --- | --- |
| A（现建议） | 绝对路径根处钳住，相对路径保留前导 `..` | 相对/绝对分叉依赖 Q-6；R-06 相对示例仍不可判 |
| B | 两者都在根处钳住 | 破坏 N3"`../etc` 保持不变"；相对路径语义整体改变 |
| C | 任何越界 `..` 直接返回 -1 | `normalize_to` 不再全函数；需要 Q-5 的错误码；调用方无法规范化任意输入 |
### Q-4 `char *::walk` 签名
| 选项 | 做法 | 代价 |
| --- | --- | --- |
| A（现建议） | 改为 `walk(cb, ud, max_depth)` | 破坏 `proposal.md:52`「`"src".walk(on_entry, ud)`」与 F5 源码兼容 |
| B | 保持两参数，深度只在 `FsGuard` | 删除 R-07 判据 3；无状态原语无法限深，深树风险留在调用方 |
| C | 新增 `walk_depth(cb, ud, max_depth)`，保留旧名 | API 面变大；需确认不与 22 个 std 名字冲突 |
### Q-5 第 11 个错误码
| 选项 | 做法 | 代价 |
| --- | --- | --- |
| A（现建议） | 不加码；负 offset/`len<0`→-1+IO，`len==0`→0 | 非法参数与 IO 混淆；setter 返回 NULL 时 `FS_ERR_IO` 无对象可查，和"原对象状态不变"冲突 |
| B | 新增 `FS_ERR_INVALID` | 破坏 R-02"恰有 10 个成员"与"10 码冻结"；需改 enum 与所有相关判据 |
| C | 用 -2/NULL 专用哨兵，不进 enum | 与"int 返回 + last_error"模型冲突；调用方可能把 -2 当字节数 |
### Q-6 绝对 root + 相对输入
| 选项 | 做法 | 代价 |
| --- | --- | --- |
| A（现建议） | 拒绝，返回 `OUT_OF_BOUNDS` | `check("src/a.c")` 失败；R-06 相对示例必须改；调用方必须传绝对路径 |
| B | 按 root 解析相对路径 | 需要 join+规范化；要定义 `..` 是否可逃出 root；错误 path 变为绝对路径 |
| C | 按 CWD 解析 | 与 root 语义冲突，安全上最差；不推荐 |
### Q-7 deny glob 方言
| 选项 | 做法 | 代价 |
| --- | --- | --- |
| A（现建议） | `fnmatch(FNM_PATHNAME)`：`*`/`?` 不跨 `/`、大小写敏感、全路径、目录命中跳整棵、无 `**` | 无法表达递归模式；用户可能按 gitignore 预期写 `**` |
| B | 支持 `**` 的完整 glob | 实现与测试面变大；需定义 `**` 跨段语义；APFS 大小写问题仍在 |
| C | 不做 glob，只支持精确路径/段前缀 | 表达力最弱；但最容易冻结和验收 |

## 5 统计与优先顺序

- **反对条数**：18（FSR-01…FSR-18）。
- **严重度分布**：阻断 8、需改 9、仅澄清 1。
- **"不补就没法开工"（阻断）**：8 条——FSR-01、02、03、04、07、08、09、17。
- **最该先关的三条**：
  1. **FSR-01 评审缺位**：没有 `verdict`/`D-<n>`，后面任何裁定都没有签字载体。
  2. **FSR-07 Q-3…Q-7 未裁**：5 条判据的期望值无法冻结，实现只能猜。
  3. **FSR-08 判据无命令与阈值**：没有可执行命令与门禁，修了也无法自证；建议与 FSR-17 的平台化门禁一并落。

## 6 证据附录（原始输出）

```console
# E1 评审载体与提交
$ ls -d battle docs/decisions issues
ls: battle: No such file or directory
ls: docs/decisions: No such file or directory
ls: issues: No such file or directory
rc=1
$ git log --oneline
4a6a679…71bde35 共 5 条 docs 提交，无评审/裁决提交
# E2 威胁术语计数
$ for t in TOCTOU 硬链接 挂载 PATH_MAX 符号链接环; do ...; done
TOCTOU=0
硬链接=0
挂载=0
PATH_MAX=0
符号链接环=0
```

```console
# E3 符号链接逃逸（OS 行为）
$ readlink /tmp/fsg-probe/root/evil
/tmp/fsg-probe/outside.txt
$ cat /tmp/fsg-probe/root/evil
OUTSIDE
rc=0
# E4 硬链接（OS 行为）
$ ln /tmp/fsg-probe/outside2/target.txt /tmp/fsg-probe/root2/link.txt
ln_rc=0
$ stat -f 'inode=%i nlink=%l path=%N' ...
inode=11889029 nlink=2 path=/tmp/fsg-probe/outside2/target.txt
inode=11889029 nlink=2 path=/tmp/fsg-probe/root2/link.txt
$ cat /tmp/fsg-probe/root2/link.txt
HARD
rc=0
# E5 符号链接环（OS 行为）
$ cat /tmp/fsg-probe/root/loopa
cat: /tmp/fsg-probe/root/loopa: Too many levels of symbolic links
rc=1
# E6 超长路径（OS 行为）
$ getconf PATH_MAX /
1024
rc=0
$ python3 -c "... os.stat('/tmp/fsg-probe/' + 'a'*5000) ..."
errno=63 File name too long
# E7 R-06 相对路径示例的段边界探针
$ python3 -c "def under(p,pre): ..."
'src/a.c' vs '/workspace/src' -> 0
'src2/a.c' vs '/workspace/src' -> 0
'/workspace/src/a.c' vs '/workspace/src' -> 1
rc=0
```

```console
# E8 LSan 平台支持
$ cc -fsanitize=address -g /tmp/fsg_leak.c -o /tmp/fsg_leak
cc_rc=0
$ ASAN_OPTIONS=detect_leaks=1 /tmp/fsg_leak
==53365==AddressSanitizer: detect_leaks is not supported on this platform.
run_rc=134
# E9 门禁缺失
$ ls -d tools
ls: tools: No such file or directory
rc=1
$ grep -c '^\$ ' docs/requirements.md
0
grep_rc=1
# E10 `NOT_DIR` 与待确认计数
$ grep -n 'FS_ERR_NOT_DIR' docs/proposal.md docs/requirements.md
docs/proposal.md:106:#define FS_ERR_NOT_DIR          6
docs/requirements.md:46:- **改后口径**：`pub enum FsErrCode { ... FS_ERR_NOT_DIR = 6 ... }`
$ grep -c 'TBD' docs/requirements.md
0
$ grep -c '待确认' docs/requirements.md
6
```
