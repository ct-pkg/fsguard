# FSG-02 `ct install` 不识别 `.m.ct`：只 import 映射单元的消费者被误判为无法解析

id: FSG-02
status: open
opened: 2026-11-16
phase: PH-04
severity: minor
rule: 上游缺陷登记（D-015）；PKG-6 的同类项
anchor: `ct-lang/selfhost/ct-ast/tool/pkg/Pkg.h.ct:1609-1618`；本仓 `docs/decisions/D-015.md`
evidence: 见 §复现（原始输出）；`docs/reviews/fsguard-b003-battle.md` §3

## 现象

消费者只 import `.m.ct` 单元时（`std::fs::Fs`、`std::str::String` 都是 `.m.ct`），
`ct install` 的 import 校验报 `cannot resolve import`，rc=1；同一工程 `ct build` + 运行正常。

## 复现

```console
$ cd /tmp/fsg-install-probe
$ cat ct.pkg
...
dep = std@0.3.2
$ cat main.ct
import std::fs::Fs;

int main(void)
{
    return ".".exists() ? 0 : 1;
}
$ ct get std@0.3.2
installed 1 package(s)
$ ct install
ctc: 'main.ct' cannot resolve import 'std/fs/Fs'
INSTALL_RC=1
$ ct build main.ct -o probe
'cc' -std=c99 -I '/Users/samxx/.ct/pkg/std/std/0.3.2/std/fs' -I '.ctbuild' '.ctbuild/main.c' '-o' 'probe'
BUILD_RC=0
$ ./probe; echo $?
0
```

同一消费者换成 `.h.ct` 形态的 import（例如 `std::io::Io`）时 `ct install` rc=0。

## 根因

`ct-lang/selfhost/ct-ast/tool/pkg/Pkg.h.ct:1609-1618` 的 import 校验只 stat 两种单元文件：

```c
if (snprintf(cand, sizeof cand, "%s.h.ct", rel) < (int)sizeof cand
    && stat(cand, &st) == 0 && S_ISREG(st.st_mode)) seen = 1;
if (!seen && snprintf(cand, sizeof cand, "%s.ct", rel) < (int)sizeof cand
    && stat(cand, &st) == 0 && S_ISREG(st.st_mode)) seen = 1;
```

漏掉 `%s.m.ct`。映射单元（`map trait` 只能写在 `.m.ct`）因此一律被判为不可解析。

## 影响

- `ct install` 的 rc 在 `.m.ct` 消费者上不可作为验收信号；`ct install` rc=0 也不等于 import 可解析（PKG-6）。
- 本仓 R-03 的验收按 D-015 改走 `ct build` + 运行，不受阻；`g3-ph04 r03` 正常判绿。
- 不改 ct-lang、不 vendor、不在门禁里自算包含根。

## 处置

- 2026-11-17 在 `ct v0.62.0` 上复现：消费者 `import std::fs::Fs;` + `dep = std@0.3.2`，
  `ct install` 仍报 `ctc: 'main.ct' cannot resolve import 'std/fs/Fs'`，rc=1；`ct build` + 运行正常。
  上游缺陷未修，本条保持 `open`。
- 本仓：D-015 已裁「门禁用 `ct build` 验收、install 红单独登记」；本条只做跟踪。
- 上游：建议在 `Pkg.h.ct` 的 import 校验中补 `%s.m.ct` 分支（与 `.h.ct` 同级）。
- 关闭条件：上游修复并发布后，在 `.m.ct` 消费者上 `ct install` rc=0；届时本条转 `fixed`，可把 install 冒烟作为附加证据加回门禁（主验收仍是 build + 运行）。
