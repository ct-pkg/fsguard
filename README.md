# fsguard

`std::fs` 之上的词法路径策略层：`char *` 上的无状态原语 + `FsGuard` 有状态检查。

- 状态：**评估已完成、未立项**。
- 边界：**这是词法策略层，不是安全边界；不解析符号链接。**
- 代码待立项后开。

## 文档

- [提案原文](docs/proposal.md)
- [评估结论](docs/analysis.md)
- [需求分析](docs/requirements.md)
- [设计待决项](docs/design.md)
- [会话映射](docs/session-map.md)
