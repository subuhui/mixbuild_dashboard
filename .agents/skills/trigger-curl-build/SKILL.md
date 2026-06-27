---
name: trigger-curl-build
description: 触发本地 MixBuild Dashboard 服务的 curl 构建任务
---

# 触发 MixBuild Dashboard 远程构建 (curl)

此技能用于协助助手在用户请求时，自动构造并执行 `curl` 命令以远程触发 MixBuild 仪盘面板的构建流水线。

## 执行规则

1. **项目及分支获取 (默认规则)**：
   * **若用户未显式指定构建场景名称 (scenario)**：
     * **项目名称 (project)**：获取当前项目的文件夹名称（即工作区根目录的 basename）作为 `project` 参数值。
     * **分支名称 (branch)**：运行 Git 命令（如 `git branch --show-current`）获取本地当前分支，作为 `branch` 参数值。
   * **若用户指定了构建场景名称 (scenario)**：
     * 优先使用该场景名称作为 `"scenario"` 参数传入。
     * 目标分支默认为当前 Git 分支（或用户指定的分支）。

2. **触发端点 (Endpoint)**：
   * 本地默认服务地址：`http://127.0.0.1:8765/build`

3. **构造并执行 curl 命令**：
   * **情况 A：通过项目名称触发 (默认情况)**：
     ```bash
     curl -X POST http://127.0.0.1:8765/build \
       -H "Content-Type: application/json" \
       -d '{"project": "<project_name>", "branch": "<branch_name>"}'
     ```
   * **情况 B：通过场景名称触发 (用户已指定)**：
     ```bash
     curl -X POST http://127.0.0.1:8765/build \
       -H "Content-Type: application/json" \
       -d '{"scenario": "<scenario_name>", "branch": "<branch_name>"}'
     ```

## 助手操作指南

1. 分析用户输入的指令。
2. 若需要获取当前文件夹名或当前分支，通过 `run_command` 运行 `basename "$PWD"` 和 `git branch --show-current`（或由系统 metadata 直接读取）。
3. 组合出正确的 `curl` 命令并使用 `run_command` 触发构建。
4. 返回执行结果并解析服务器响应（例如 `202 Accepted`）。
