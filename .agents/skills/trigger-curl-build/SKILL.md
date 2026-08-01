---
name: trigger-curl-build
description: 触发本地 MixBuild Dashboard 服务的 curl 构建任务
---

# 触发 MixBuild Dashboard 远程构建 (curl)

此技能用于协助助手在用户请求时，自动构造并执行 `curl` 命令以远程触发 MixBuild 仪表盘的构建流水线。

## 执行规则

1. 若用户未指定构建场景，使用当前项目目录名作为 `project`，当前 Git 分支作为 `branch`。
2. 若用户指定了构建场景，使用场景名称作为 `scenario`，当前 Git 分支或用户指定分支作为 `branch`。
3. 默认端点为 `http://127.0.0.1:8765/build`；若仪表盘设置了其他端口，使用实际端口。
4. 若用户提供更新说明，在 JSON 中增加可选的 `update_description`；未提供时由服务使用场景默认值。

通过项目名称触发：

```bash
curl -X POST http://127.0.0.1:8765/build \
  -H "Content-Type: application/json" \
  -d '{"project": "<project_name>", "branch": "<branch_name>"}'
```

通过场景名称触发：

```bash
curl -X POST http://127.0.0.1:8765/build \
  -H "Content-Type: application/json" \
  -d '{"scenario": "<scenario_name>", "branch": "<branch_name>", "update_description": "<update_description>"}'
```

执行后解析服务响应，并向用户说明是否返回 `202 Accepted`。
