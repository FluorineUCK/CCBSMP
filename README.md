# CCBSMP

私有仓库：https://github.com/FluorineUCK/CCBSMP

## 项目结构

```text
pack/
  pack.toml             # Minecraft、NeoForge、整合包候选版本
  index.toml            # 文件索引和哈希
  .packwizignore        # 不进入整合包的目录标记
  mods/                 # jei.pw.toml、imblocker.pw.toml 等模组元数据
  config/               # 经审查的整合包配置
  defaultconfigs/       # 新世界默认服务端配置
  kubejs/               # 脚本与资源
  hotai/                # 按内部类名路径组织的补丁或下载元数据
deploy/                # 与 pack 同级，不参与客户端文件索引
  server.properties.example
  automodpack/          # 无凭据模板
tools/                 # 与 pack 同级：校验、构建、部署脚本
CHANGELOG.md
README.md
.gitignore
.gitattributes
```

## 当前状态

本次仅完成结构调整。`pack/index.toml` 当前为空，不能用它替代完整整合包。
`jei.pw.toml`、`imblocker.pw.toml` 是后续导入时的命名示例，尚未创建虚构的下载地址或哈希。
现用 Test 中的模组、配置和 Hotai 补丁尚未迁入本仓库；Test 与正式服务器均未被修改。
候选版本为 1.1.0-rc.1，游戏版本 Minecraft 1.21.1 / NeoForge 21.1.265。

## 模组与索引

模组使用 packwiz `.pw.toml`，记录名称、目标文件名、安装侧、真实下载来源和内容哈希。
安装侧使用 `client`、`server` 或 `both`，不依靠文件名猜测。
文件变动后在 `pack/` 内运行 `packwiz refresh` 更新索引及 pack.toml 中的索引哈希。
`pack/config` 不是运行实例 config 的全量副本；个人偏好、凭据与缓存不导入。
部署模板不纳入 pack 索引，且不会自动覆盖正式服配置。

## Hotai 同样版本化

- `pack/hotai/<内部类路径>.badiff` 可作为受控文件直接提交，由 index.toml 记录哈希。
- 外部托管补丁可用 `pack/hotai/<内部类路径>.pw.toml`，其 filename 指向同目录下的 `.badiff`，并填写安装侧、固定下载地址和哈希。
- 这两种方式对同一个补丁只选一种，不重复分发。
- `.class` 是编写/转换阶段的完整类替换；稳定发布优先使用经过 Hotai 转换、测试的 `.badiff`。
- 在 `tools/hotai/` 维护补丁制作说明或生成脚本，记录目标模组 ID/版本、原始 JAR SHA256、目标类、补丁哈希、安装侧、测试结果。这些约束不是 packwiz 自动验证项，后续校验工具需明确检查。
- 不给全局 `.class`/`.badiff` 忽略规则，避免受控补丁被漏掉；构建临时文件仍放在被忽略的 build/ 下。
- 不为当前已禁用的模组自动启用旧补丁；原模组升级后必须重新验证补丁。

## Git 与发布边界

main 保存经审查的源码变更；测试改动用 update/* 分支，正式发布后创建版本标签。
Git push 不部署、不重启服务器。世界、玩家数据和身份数据库单独备份，不进入 Git。
第三方 JAR、构建包和下载缓存不入库；本仓库只管理其下载元数据。
提交前检查 `git diff --cached`，发布前审查最终文件索引。

## 下一步

从 Test 导入完整模组元数据、补齐前置并筛选受控配置；随后导入经验证的 Hotai 补丁，再实现构建、验证与 AutoModpack 发布流程。

格式参考：https://packwiz.infra.link/reference/pack-format/pack-toml/
