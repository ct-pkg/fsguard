# FSG-01 版本链断裂：`ct.pkg` 仍是 0.1.0，PH-02/03/04 的 `version-minor` 已到 2/3/4

id: FSG-01
status: open
opened: 2026-11-16
phase: PH-04
severity: major
rule: 6.7 V-1（MINOR 与 phase 一一对应）、V-5（版本随事同提交）、V-6（版本不一致即缺陷，须立案）；G0「版本落点」；G6（版本不一致未立案即失败）
anchor: `ct.pkg:14`；`docs/phases/PH-02/card.md:7`；`docs/phases/PH-03/card.md:7`；`docs/phases/PH-04/card.md:7`；`AGENTS.md:271`（偏离项：无）
evidence: 见 §复现（三组命令的原始输出）

## 现象

项目产品版本 `ct.pkg#version` 自 PH-01 起停在 `0.1.0`；PH-02、PH-03 收口时都没有移动版本，也没有 CHANGELOG、没有版本 tag、`AGENTS.md` 0.3 记「无偏离」。按 6.7 V-1，`PH-<n>` 收口时 `MINOR` 应等于 `n`，三次收口各缺一次 +1；按 V-6，这属于缺陷，不得记为历史遗留或 `deferred`。

## 复现

```console
$ grep -n '^version' ct.pkg
14:version = 0.1.0
$ grep -n '^version-minor:' docs/phases/PH-0*/card.md
docs/phases/PH-01/card.md:7:version-minor: 1
docs/phases/PH-02/card.md:7:version-minor: 2
docs/phases/PH-03/card.md:7:version-minor: 3
docs/phases/PH-04/card.md:7:version-minor: 4
$ git tag -l
backup/pre-s4-rollback
$ ls CHANGELOG*
zsh:1: no matches found: CHANGELOG*
$ grep -n '^| 偏离项' AGENTS.md
271:| 偏离项 | 无（见 0.3） |
```

结论：`MINOR(1) != PH-04 的 version-minor(4)`，偏移 `d = 4 - 1 = 3`；仓库无版本 tag、无 CHANGELOG、无用户签字的 `deviation:`。

## 影响

- G0 的 `版本落点` 声明与实值可对上（落点唯一且为 `ct.pkg#version`），但 G1 `g1-version` 用 `PH-<n>` 核对会失败（当前 `tools/check.sh` 未实现 `g1-version`，属实现缺口，不在本条内修）。
- 已收口的 PH-02、PH-03 若按 V-1 复核，收口提交的版本均未 +MINOR，属存量落差。
- 本条不改变任何运行期行为；`bash tools/check.sh all` 在立案前后同为 rc=0。

## 本轮处置（不做）

用户指令：本轮不 bump 版本、不打 tag、不登记偏离。因此只立案，`status: open`，版本号保持 `0.1.0`。

## 待裁定（需用户签字，三选一）

按 6.7「存量落差的偏离」与 C-6，收敛方式必须写死一种：

| 选项 | 写法 | 代价 |
| --- | --- | --- |
| A 一次性补号 | 指定某次收口把 MINOR 一次补到 `n`（PH-04 即补到 4） | 该次收口违反「不许多跳」，须在同一条 `deviation:` 里显式豁免 |
| B 永久偏移 | `deviation: 偏移 3`，每轮按 `n - 3` 换算 | 版本号与 phase 长期错位 |
| C 将来重编号 | 写明到 `PH-<m>` 时重编号 | 届时一次跳号，CHANGELOG 留空段 |

无论选哪项，都需在 `AGENTS.md` 0.3 写全 `deviation:` 六个字段并签字；在此之前本条保持 `open`，PH-04 不得因本条被宣称收口（PH-04 另有后半四项挂起，本身也不得收口）。
