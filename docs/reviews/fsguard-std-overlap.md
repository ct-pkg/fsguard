# fsguard 与 std 的符号级对照

> 目的：拿 `ct-pkg/std` 的实际能力重判 fsguard，回答「哪些是重复造轮子、哪些确实该由 fsguard 提供」。
> std 仓库只读核对：`git@github.com:ct-pkg/std.git`，`main` 在 `b04b7d6`，tag `v0.2.0`。
> 本文件只记录事实与对照，结论另见 `docs/decisions/D-011.md`。

## 1 安装方式与落盘位置（本机实测）

`~/.local/bin/ct` 为 v0.53.0。机器上没有全局包目录，CT 的安装模型是**按消费者项目 vendor**：

```console
$ cd ct-fsguard
$ ct get file:///tmp/ct-pkg-std
vendored 1 package(s)
$ cat ct.lock
std 0.2.0 dir /tmp/ct-pkg-std sha256:cee740b3a4edc006cc8910e320f9b7ff90dbdc75b4f516eea1d710f6bdccae26
$ ct verify
verified 1 package(s)
$ ct install
ct build -I vendor/std --ldflags '-lm' <unit>.ct -o build
```

- 落盘位置：`<消费者>/vendor/std/`，摘要写进 `<消费者>/ct.lock`；没有 `~/.ct/` 之类的全局目录。
- import 方式：`import std::fs::Fs;`，编译加 `-I vendor/std`。
  命名空间根是包内的 `std/` 子目录，于是 `vendor/std` + `std/fs/Fs.m.ct` 两级拼出 `std::fs`。
- `ct get` 会把来源写进 `ct.pkg` 的 `dep`（本地目录形态为 `dep = file:///…`）；`ct install` 只读 `vendor/` 与 `ct.lock`，零网络。
- `std` 的 `ldflags = -lm` 会被 `ct install` 折进建议命令；`cflags` 未声明。

fsguard 侧本次是**探针式安装**：装进 `ct-fsguard/vendor/std` 跑完对照后移除，`ct.pkg` 不保留 `dep`（理由见 D-011）。复现命令同上。

## 2 std 与 fsguard 相关的公开面

| 模块 | 形态 | 与本次相关的公开符号 |
| --- | --- | --- |
| `std::fs::Fs` | `.m.ct` + shim，宿主 `char *` | `exists()`、`readFile(out, cap)`、`writeFile(data)`、`list(out, cap)` |
| `std::io::File` | `.m.ct` + shim | `char *::open(mode)`、`IoFile *::read/write/close`；`IoFile` 是不透明句柄 |
| `std::io::Io` / `Stdout` | `.h.ct` / `.m.ct` | `std::io::printf`、`puts`、`putchar`、`getchar`、`fflush` |
| `std::str::String` | `.m.ct` + shim，宿主 `char *` | `len`、`find`、`findChar`、`startsWith`、`endsWith`、`copy`、`slice`、`concat`、`toLower`、`toUpper`、`compare`、`copyTo`、`toInt`、`toDouble` |
| `std::test::Test` | `.h.ct` | `init`、`checkTrue`、`checkEqInt`、`checkEqStr`、`report` |
| `std::vec` / `std::map` / `std::arena` | `.h.ct` | `VecInt` / `VecStr`、`MapStrInt` / `MapIntPtr`、`Arena` |

std 明确不提供的（`std/fs/README.md` §8、`std/io/README.md` §1）：路径规范化、段边界判定、递归遍历、目录项类型、errno / 错误码、`seek`。

## 3 符号级对照表

关系分四类：**无对应**（std 没有，fsguard 该提供）、**同形不可替代**（看起来像，但语义/错误模型不同）、**构件**（std 只有积木，没有该语义）、**不重复**（各管一摊）。

| fsguard 符号 | std 对应 | 关系 | 判据 |
| --- | --- | --- | --- |
| `FsErrCode`（10 值） | 无 | 无对应 | std 全部失败只给 `-1`，`std::fs` README 明写「没有 errno / 错误码」；R-14 的分类无法表达 |
| `FsError` / `last_error()` / `has_error()` / `clear_error()` | 无 | 无对应 | std 无错误对象、无 per-handle 状态 |
| `FsGuard`（root / allow / deny / max_depth） | 无 | 无对应 | std 无状态、无策略 |
| `FsGuard::check` | 无 | 无对应 | std 无路径策略判定 |
| `char *::normalize_to` | `std::str` 的 `find`/`findChar`/`slice`/`copy` | 构件 | std 只给字节切分，没有 `..` 折叠、`.` 消去、重复 `/` 压缩；见 `r05_normalize` 13 checks |
| `char *::is_under` | `startsWith(prefix)` | 构件 | `startsWith` 是字符串前缀，`/a/bc` 会误判在 `/a/b` 下；fsguard 按段边界判定 |
| `char *::read_chunk` / `FsGuard::read_chunk` | `IoFile::read`（无 offset） | 无对应 | std 无 `seek`/offset；且 `read` 失败只给 `-1` |
| `char *::walk` / `FsGuard::walk` | `char *::list(out, cap)` | 同形不可替代 | `list` 单层、把名字用 `\n` 拼进一个缓冲、不区分文件/目录、不递归、不可剪枝；walker 需要 `lstat` 类型、深度、回调中止、deny 剪枝与 fail-closed |
| `FsGuard::read_file` | `char *::readFile(out, cap)` | 同形不可替代 | 都是「整文件进调用方缓冲 + cap 含 NUL」，但 std 无 errno、目录返回 0（见 §5），失败不可分类；fsguard 需要 `NOT_FOUND`/`PERMISSION`/`IS_DIR`/`BUFFER_TOO_SMALL`/`OOM` |
| `FsGuard::write_file` | `char *::writeFile(data)` | 同形不可替代 | std 按 `strlen` 写（不能含 NUL）、成功返回 0、失败 `-1`；fsguard 按 `len` 写二进制、成功返回 `len`、失败给码（D-006） |
| `fsguard_new` | 无 | 无对应 | std 无对象构造 |
| `fsgo_errno()`（shim 内部） | 无 | 无对应 | std 不暴露 errno；宏对 CT 不可见，只能用 C 访问器 |
| 无 | `exists()` | 不重复 | fsguard 不提供存在性判断，也不需要提供 |
| 无 | `char *::open(mode)` / `IoFile::read/write/close` | 不重复 | fsguard 不导出句柄；`read_chunk` 要 offset + errno，不复用 stdio 句柄 |
| 无 | `std::io::printf` / `Stdout.*` | 不重复 | 输出归 std |
| 无 | `std::str` 14 个方法 | 不重复 | 字符串工具归 std；fsguard 的 shim 是 C，跨包调用这些 `static inline` 不成立 |
| 无 | `Vec` / `Map` / `Arena` / `Test` | 不重复 | 容器与测试框架归 std |

**交集为空**：fsguard 占用的 `char *` 方法名是 `normalize_to` / `is_under` / `read_chunk` / `walk`；std 占用 `exists` / `readFile` / `writeFile` / `list` / `open` / `read` / `write` / `close` / `len` / `find` / `findChar` / `startsWith` / `endsWith` / `copy` / `slice` / `concat` / `toLower` / `toUpper` / `compare` / `copyTo` / `toInt` / `toDouble`。同一单元同时 import 两者可以编译并运行（§4）。

## 4 共存验证（同一编译单元 import 两个包）

```ct
import fsguard::FsGuard;
import fsguard::FsGuardOps;
import std::fs::Fs;

int main(void)
{
    char norm[256];
    char buf[64];
    int n;

    "/tmp/a/../b".normalize_to(norm, 256);
    if (!"/tmp".exists()) return 1;
    if ("/tmp/coexist.txt".writeFile("hi") != 0) return 2;
    n = "/tmp/coexist.txt".readFile(buf, 64);
    if (n != 2) return 3;
    if ("/tmp/coexist.txt".is_under("/tmp") != 1) return 4;
    return 0;
}
```

```console
$ ct build /tmp/coexist.ct -I src -I vendor/std --cflags "-Isrc" -o /tmp/coexist
'cc' -std=c99 -Isrc -I 'src/fsguard' -I 'vendor/std/std/fs' -I '.ctbuild' \
     '.ctbuild/coexist.c' '.ctbuild/FsGuard.c' '-o' '/tmp/coexist'
$ /tmp/coexist; echo $?
0
```

两个 `-I` 根可以并存，`cc` 行按单元把各自模块目录加进来；没有方法名冲突。

## 5 语义冲突与「谁对」

| 场景 | std 实测 | fsguard 实测 | 判定 |
| --- | --- | --- | --- |
| 读目录 | `readFile` 返回 **0** | `FS_ERR_IS_DIR`（5） | fsguard 对：`read(2)` 对目录返回 `EISDIR`，返回 0 等于把目录当空文件 |
| 读无权限文件 | `-1` | `FS_ERR_PERMISSION`（2） | fsguard 对：失败必须可分类（R-14）；std 的 `-1` 无法区分 |
| 写目录 | `-1` | `FS_ERR_IS_DIR`（5） | fsguard 对（同上） |
| 写含 `\0` 的数据 | 按 `strlen` 截断 | 按 `len` 全写 | fsguard 对：二进制写是 R-12 的要求；std 的限制已写进自己的 README |
| 成功返回值 | `writeFile` 返 0 | `write_file` 返 `len` | 风格不同，不算冲突；fsguard 的码/长度模型服务策略层 |
| 符号链接 | `exists` 用 `stat`（跟随） | `walk` 用 `lstat`（不跟随） | 不同层：std 判存在，fsguard 做策略遍历；文档已声明不解析符号链接 |

实测命令（同一单元里两边对照）：

```console
$ /tmp/errmodel
std  missing=-1
std  dir=0
fsg  missing=1
fsg  dir=5
$ /tmp/errmodel2
std  locked=-1
fsg  locked=2
std  write-dir=-1
fsg  write-dir=5
```

## 6 对 std 的建议（只出建议，未动 std 仓库）

| # | 建议 | 证据 | 影响 |
| --- | --- | --- | --- |
| S-1 | `std_fs_read_file` 在 `fopen` 后补目录/`ferror` 检查，目录应返回 `-1` | `/tmp/stdcmp/dir`.readFile 返回 0 | 现在会把目录当空文件；上层若用 `readFile` 做存在性/内容判断会误判 |
| S-2 | `std_fs_write_file` 考虑长度参数或指向 `std::io::File.write(buf, n)` | 含 `\0` 的数据被截断 | 二进制写入需要另一条路径；文档已声明，优先级低 |
| S-3 | 若要支持上层错误分类，`std::io` 可加 errno 访问器（C shim 里 `errno` 是宏，CT 侧需要访问器） | fsguard 已用 `fsgo_errno()` 绕开 | 属 std 的 API 设计选择，不建议为 fsguard 单独加 |
| S-4 | 路径规范化 / 段边界 / 递归遍历 / offset 读**不建议**进 std | std 现有定位是「四个整文件/单层原语」 | 这些语义带策略与错误码，属 fsguard；std 保持薄层更稳 |
| S-5 | 补 `mkdir` / `remove` / `rename` | `std/fs/README.md` §1 明写不提供 | 目前只能直接调 C API；若 std 增补，fsguard 也不应包装策略 |
| S-7 | `IoFile` 增加 `seek` / offset 读 | `std::io` 只有顺序 `read` | 分块读只能整读或自己用 C；fsguard 的 `read_chunk` 因此自留 |

原 S-6（`writeFile` 长度参数）与 S-2 是同一问题，已并入 S-2，不再单列。
可直接投递的建议文本见 `docs/reviews/fsguard-std-suggestions.md`。

## 7 安装与消费的边界问题（与 std 无关，但由本次安装暴露）

`ct-fsguard` 的源码在 `src/fsguard/`，而 CT 的包约定是「包根下的同名目录即命名空间根」。因此：

```console
$ cd /tmp/fsg-consumer   # ct.pkg: dep = fsguard; dep = std
$ ct get file:///Users/samxx/trae-ws/ct-fsguard
$ ct get file:///tmp/ct-pkg-std
$ ct install
ct build -I vendor/std -I vendor/fsguard --ldflags '-lm' <unit>.ct -o build
$ ct build main.ct -I vendor/std -I vendor/fsguard -o probe
ctc: cannot resolve import 'fsguard/FsGuard'
```

`ct install` 只打印 `-I vendor/<包名>`，而 fsguard 的单元在 `vendor/fsguard/src/fsguard/`，多了一层 `src`。手工加 `-I vendor/fsguard/src` 可以编译，但这不是标准消费方式；修法是 PH-04 的包形态任务（把命名空间目录上移到仓库根），不在本表范围内动。

## 8 对照结论（一句话）

**fsguard 的 12 个公开符号没有一个与 std 的公开符号重复**；最接近的 `read_file` / `write_file` 是「同形不可替代」——std 的 `-1` 错误面无法承载 fsguard 的错误码与二进制语义，`normalize_to` / `is_under` / `read_chunk` / `walk` 在 std 里没有对应物，std 的 `exists` / `list` / `String` / `io` 也不该由 fsguard 重造。

按「直接改实现、删掉重复部分」的指示逐函数复核后，**可删代码为 0 行**：

| 候选 | 能否改成依赖 std | 卡点 |
| --- | --- | --- |
| `FsGuard::read_file` | 否 | std 无 errno；目录返回 0；换掉丢 R-14 的分类 |
| `FsGuard::write_file` | 否 | std 按 `strlen`；换掉丢二进制与返回 `len`（R-12 / D-006） |
| `FsGuard::read_chunk` / `char *::read_chunk` | 否 | std 无 offset / `seek` |
| `walk` | 否 | `list` 单层 + `\n` 拼接；且 walker 在 C shim，调不到 CT 的映射方法 |
| `fsguard_errno_to_code` | 否 | std 不暴露 errno |

另一个硬约束：硬依赖 std 需要每个消费者与门禁都 `vendor/std`，而 `vendor/std` 不进版本库（主控约束），
构建会变成非自足；因此 D-011 的「零依赖」同时是工程约束。详细裁定见 `docs/decisions/D-011.md`。

