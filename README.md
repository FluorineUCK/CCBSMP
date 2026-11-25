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

已从当前 CCBSMP Test 导入 128 个启用模组的审计锁，其中 127 个已生成真实下载源的 `.pw.toml`。
导入 171 个配置、KubeJS 与 Hotai 文件；排除 40 个个人设置、缓存、备份和禁用模组配置。
`defaultconfigs/` 在 Test 中为空，保留目录。资源包与光影不在本次导入范围内。
本次快照中 ModernFix 已不在 Test 启用目录，未重新添加；未修改 Test 或正式服务器。

**尚不可完整发布：** Vanillin `1.1.3-local.starlight` 的准确发布源待匹配。没有替换为原版，也没有把 JAR 提交到仓库。
其精确文件名、哈希和安装侧保存在 `tools/test-mods.lock.json`，未伪造 `.pw.toml` 链接。
CF 原版 1.1.3 为 870344 字节，Test 构建为 123858 字节，SHA256 不同。

Hotai 按 Test 原路径保留一个 More Culling `.class` 补丁；目标 More Culling 当前禁用，补丁不意味着目标模组已启用。
`tools/hotai/patches.lock.json` 记录补丁、目标 JAR 哈希与安装侧；未运行游戏验证或转换 `.badiff`。

候选版本 1.1.0-rc.1，Minecraft 1.21.1 / NeoForge 21.1.265。

## 本地检查

Python 3.11+，不依赖第三方 Python 包：

```powershell
python tools/verify_pack.py --allow-incomplete  # 检查现有文件和索引，不代表可发布
python tools/verify_pack.py                     # 默认阻止未补齐下载源的发布
python -m unittest discover -s tools -p "test_*.py"
```

`tools/import_test.py --source <实例目录>` 按已核对的审计锁导入，不下载模组、不修改实例、不自动删除仓库文件。
再次导入前先审阅源文件变化并更新锁；删除/排除已有文件需显式审核，校验器会拒绝未纳入索引的文件。
`tools/import-report.json` 列出所有导入、排除与未匹配项；审计锁不替代 packwiz 发布元数据。

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

补齐 local.starlight 的精确发布来源，再进行干净实例重建、安装侧复核与 AutoModpack 集成。当前记录的安装侧来自服务端基线及明确计划，不代表已经完成专用服务端运行验证。

格式参考：https://packwiz.infra.link/reference/pack-format/pack-toml/
