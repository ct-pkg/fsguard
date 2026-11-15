# 决策记录（D）编号与签字规则

- **D 编号**：从 `D-001` 起，三位零填充，一文件一决策；按实际创建顺序分配，不预分配。
- **V 编号**：从 `V-001` 起，一文件一轮裁决；`V-001` 即 `docs/reviews/fsguard-verdict.md`。
- **本轮实际分配**：`D-001` = Q-5（非法参数错误码）；`D-002` = Q-6（绝对 root + 相对输入）；`D-003` = Q-3（`..` 消解）；`D-004` = Q-4（`char *::walk` 深度参数）；`D-005` = Q-7（deny glob 方言）；`D-006` = Q-2（`write_file` 失败语义）；`D-007` = H-3（R-06 判据 1 示例）；`D-008` = H-4（R-05 重叠必须拒绝）；`D-009` = H-8（`ENOTDIR` 映射）。
- **本轮状态**：D-001…D-009 均已裁；签字方：主控（用户授权）。
- **历史说明**：`V-001` §4 里的 `D-001…D-010` 预分配表只是建议，自本文件起作废，以实际 `D-*.md` 为准。
- **状态值**：`draft（待签）` / `accepted` / `rejected` / `superseded`。
- **签字分工**：EDITOR 写 `verdict`/`judge`；REQ 写 `trigger`/`scope`；ARCH 写 `criteria` 与证据。
- **固定字段（13 个）**：`id/date/anchor/status/trigger/verdict/judge/seats/scope/criteria/rationale/invalidation/affected`。
- **校验**：`bash tools/check.sh g0-decisions`（检查索引、V-001 标记、D 文件与 13 字段）。

## 文件模板

```text
# D-00x <标题>

id: D-00x
date: YYYY-MM-DD
anchor: docs/reviews/fsguard-verdict.md#<锚点>
status: draft（待签）
trigger: FSR-xx / Q-x
verdict: 待签
judge: 待签
seats: proposer=REQ; opposition=REVIEW; evidence=ARCH
scope: R-xx, R-yy
criteria: 见 §判据
rationale: 见 §推荐
invalidation: 见 §失效条件
affected: 受影响的文档与判据

## 判据
## 推荐
## 代价
## 若选另一案会打破什么
## 失效条件
```
