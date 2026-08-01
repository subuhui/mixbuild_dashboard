# MixBuild Dashboard UI/UX 优化实施计划

**目标：** 在不改变构建、配置和持久化业务逻辑的前提下，修复影响判断准确性的交互问题，并提高桌面工具的信息密度、可访问性和键盘操作效率。

**范围：** YAML 编辑器、构建详情、构建日志、响应式布局、全局导航、设置页和通用主题。计划以 2026-08-01 的最新界面截图为视觉基线。

**非目标：** 不重做路由结构，不修改构建协议，不新增业务功能，不恢复已经废弃的 `default_branch`，不进行与 UI/交互无关的重构。

---

## 视觉基线

| 页面/状态 | 截图 |
|---|---|
| 全局仪表盘 | [20260801172732.jpg](../../../stitch_design/screenshots/20260801172732.jpg) |
| YAML 编辑器 | [20260801172801.jpg](../../../stitch_design/screenshots/20260801172801.jpg) |
| 项目编辑：工作区扫描 | [20260801172816.jpg](../../../stitch_design/screenshots/20260801172816.jpg) |
| 项目编辑：依赖拓扑 | [20260801172824.jpg](../../../stitch_design/screenshots/20260801172824.jpg) |
| 项目编辑：构建场景矩阵 | [20260801172830.jpg](../../../stitch_design/screenshots/20260801172830.jpg) |
| 新增场景：基本信息 | [20260801172849.jpg](../../../stitch_design/screenshots/20260801172849.jpg) |
| 新增场景：依赖与高级选项 | [20260801172858.jpg](../../../stitch_design/screenshots/20260801172858.jpg) |
| 项目详情：空闲状态 | [20260801172909.jpg](../../../stitch_design/screenshots/20260801172909.jpg) |
| 构建日志历史 | [20260801172916.jpg](../../../stitch_design/screenshots/20260801172916.jpg) |
| 设置：主题与构建服务 | [20260801172922.jpg](../../../stitch_design/screenshots/20260801172922.jpg) |
| 设置：Curl 与数据管理 | [20260801172930.jpg](../../../stitch_design/screenshots/20260801172930.jpg) |

## 当前结论

现有界面已经具备完整页面体系、稳定的主操作位置和清晰的构建配置/日志分栏。优先优化项不是整体换肤，而是以下会直接影响使用结果的问题：

1. YAML 行号不会随内容更新，行号区与正文区独立滚动。
2. YAML 页的复制图标不可操作，关闭和取消没有未保存保护。
3. 构建阶段条漏掉实际状态 `RESTORING`，完成、失败和中断没有终态表达。
4. 日志搜索框空闲时显示“没有匹配的记录”。
5. 响应式断点全部为 `1024`，`isMedium` 永远不会生效。
6. 提示文字和未激活步骤对比度不足；当前提示文字在浅色模式约为 `1.95:1`，暗色模式约为 `2.89:1`。
7. “支持”“文档”等导航项没有点击行为；清除日志与普通数据操作视觉权重相同。

---

## 实施原则

- 每个改动必须对应本计划中的问题或验收标准。
- 优先修复状态准确性、编辑可靠性和错误反馈，再调整视觉密度。
- 保留 Material 3 和现有蓝色品牌色，不引入新的 UI 框架。
- 使用语义颜色和主题 Token，不在页面中新增零散硬编码颜色。
- 桌面端以鼠标和键盘并重；不套用移动端的大触控间距。
- 保留现有中英文状态标识，中文说明承担解释职责。

---

### Task 1：建立交互与状态回归测试

**文件：**

- 修改：`test/responsive_layout_test.dart`
- 新增：`test/yaml_editor_page_test.dart`
- 修改：`test/log_viewport_test.dart`
- 新增：`test/project_detail_status_test.dart`

- [ ] 为 1024、1280、1440 三档逻辑宽度增加断点断言，确保 compact、medium、wide 各自可达。
- [ ] 为 YAML 新增/删除行、滚动同步、未保存退出和保存错误增加 Widget 测试。
- [ ] 断言空查询时搜索框显示“搜索日志”，仅在有查询且无结果时显示无匹配提示。
- [ ] 覆盖 `RESTORING`、`SUCCESS`、`FAILED`、`INTERRUPTED` 的阶段条表达。

**验收：** 新测试在生产代码修改前能够暴露现有问题，修改后全部通过。

### Task 2：修复 YAML 编辑器可靠性

**文件：**

- 修改：`lib/ui/yaml_editor_page.dart`
- 修改：`lib/ui/dashboard_home_page.dart`
- 视需要修改：`lib/services/mixbuild_yaml_store.dart`
- 测试：`test/yaml_editor_page_test.dart`

- [ ] 让行号数量随正文内容实时更新。
- [ ] 行号区与正文区使用同一垂直滚动位置，长文件滚动后仍保持对应。
- [ ] 把文件栏复制图标改为可操作按钮，补充 Tooltip 和复制成功反馈。
- [ ] 保存前执行 YAML 解析；解析失败时保留编辑页并显示原因和可定位的行列信息。
- [ ] 编辑内容变化后，关闭、返回和取消都需要确认是否放弃修改。
- [ ] 增加 `Cmd/Ctrl + S` 保存和 `Esc` 关闭/取消行为。
- [ ] 保存成功后再关闭页面，避免先退出再暴露持久化错误。

**验收：** 200 行以上 YAML 编辑、滚动、增删行和保存失败均不会造成行号错位或内容丢失。

### Task 3：修正构建状态与日志反馈

**文件：**

- 修改：`lib/ui/project_detail_page.dart`
- 修改：`lib/ui/build_logs_page.dart`
- 修改：`lib/l10n/app_strings_zh.dart`
- 修改：`lib/l10n/app_strings_en.dart`
- 测试：`test/project_detail_status_test.dart`
- 测试：`test/log_viewport_test.dart`

- [ ] 将 `RESTORING` 纳入阶段条，顺序与构建引擎一致。
- [ ] 为成功、失败和中断增加明确终态，不让完成后的阶段条退回无高亮状态。
- [ ] 日志搜索占位文案改为“搜索日志”，英文同步调整。
- [ ] 无结果提示只在查询非空时显示，并保留清除查询入口。
- [ ] 为日志下载和 Curl 复制按钮补齐 Tooltip 与完成反馈。
- [ ] 增加 `Cmd/Ctrl + F` 聚焦日志搜索；构建历史支持上下方向键切换记录。

**验收：** 任一构建状态都能在阶段条中找到唯一、明确的当前位置或终态；空搜索不再显示错误语义。

### Task 4：修复响应式断点并提高桌面信息密度

**文件：**

- 修改：`lib/app/responsive_layout.dart`
- 修改：`lib/ui/dashboard_home_page.dart`
- 修改：`lib/ui/project_detail_page.dart`
- 修改：`lib/ui/project_editor_page.dart`
- 修改：`lib/ui/build_logs_page.dart`
- 测试：`test/responsive_layout_test.dart`
- 测试：`test/native_window_constraints_test.dart`

- [ ] 定义互不重叠的 compact、medium、wide 断点，并记录每档布局规则。
- [ ] 在接近最小窗口宽度时收起全局侧栏，避免 300px 导航与窄主区同时存在。
- [ ] 项目详情在中等宽度使用更窄侧栏，在紧凑宽度改为上下布局。
- [ ] 构建日志历史栏按窗口宽度自适应，不固定占用 360px。
- [ ] 将主要面板圆角统一为 16px 左右，内部卡片使用 10–12px；纵向间距整体减少约 20%。
- [ ] 项目编辑场景卡使用自适应网格，避免单卡时固定 392px 造成大片无效空白。

**验收：** 1024×720、1280×800、1440×900 下无溢出、遮挡和无法触达的操作；同一窗口可比当前多展示至少一条项目场景或历史记录。

### Task 5：提高颜色对比度、焦点与动效可访问性

**文件：**

- 修改：`lib/app/mixbuild_theme.dart`
- 修改：`lib/ui/dashboard_widgets.dart`
- 修改：受影响的页面组件
- 新增或修改：主题 Widget 测试

- [ ] 调整提示文字 Token，不再通过 `muted × 50%` 生成小字号文本。
- [ ] 普通文字和输入提示在明暗主题下达到至少 `4.5:1`；大字号和非文本图形达到至少 `3:1`。
- [ ] 未激活流水线步骤仍可辨认，不能只依赖极低透明度区分。
- [ ] 检查 Tab 顺序并确保焦点轮廓可见。
- [ ] 为无文字图标按钮补齐 Tooltip/Semantics。
- [ ] `StatusChip` 的循环脉冲在系统关闭动画时停止。

**验收：** 明暗主题均通过对比度核对；只使用键盘可以完成打开项目、选择场景、开始构建、搜索日志和保存编辑。

### Task 6：清理导航和设置页视觉语义

**文件：**

- 修改：`lib/ui/dashboard_home_page.dart`
- 修改：`lib/ui/settings_page.dart`
- 修改：`lib/ui/dashboard_widgets.dart`

- [ ] “支持”“文档”接通有效入口；如果没有目标页面则暂时移除，不保留无行为导航项。
- [ ] 项目 Emoji 改为与 Flutter、Android、iOS 类型对应的统一矢量图标。
- [ ] 删除设置页重复的“外观”标题层级，保留一个页面标题和一个区块标题。
- [ ] 清除日志使用危险色，并与导入、导出操作在视觉上分组。
- [ ] 保留现有清除日志确认框，确认按钮使用危险操作样式。
- [ ] 减少窗口标题、侧栏品牌和页面标题之间的重复信息。

**验收：** 页面中不存在看似可点击却无行为的控件；危险操作与普通操作可以在不阅读说明时被区分。

---

## 全量验证

完成各任务后运行：

```bash
HOME=/private/tmp DART_SUPPRESS_ANALYTICS=true /Users/develop-mbp-02/fvm/versions/3.44.7/bin/flutter analyze
HOME=/private/tmp DART_SUPPRESS_ANALYTICS=true /Users/develop-mbp-02/fvm/versions/3.44.7/bin/flutter test
```

手工验证矩阵：

- macOS：1024×720、1280×800、1440×900
- 浅色、暗色、跟随系统三种主题
- 鼠标流程与纯键盘流程
- 空数据、空闲、RESTORING、构建中、成功、失败、中断状态
- YAML 未修改、已修改、语法错误、长文件四种情况

## 交付顺序

1. Task 1–3：先解决编辑可靠性和状态准确性。
2. Task 4：统一响应式布局并提高信息密度。
3. Task 5–6：完成可访问性和视觉语义收尾。

每个阶段单独提交，避免视觉调整与状态逻辑修复混在同一提交中。
