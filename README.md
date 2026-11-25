# CCBSMP

仓库：https://github.com/FluorineUCK/CCBSMP

![1795633339104](image/README/1795633339104.png)

欢迎，这里是CCBSMP的仓库

你可以在这里找到CCBSMP使用的所有模组（的下载路径），kjs脚本，或者hotai补丁。如果你对共同维护这个项目感兴趣，欢迎以PR的形式向服务器投稿配方/修复/兼容，它们将会以热更新的方式添加到服务器中。或者，你希望某些新模组出现在这个服务器/希望某些模组赶紧消失，你可以在issue提供你的意见，我们会根据支持率（比投票更好！）来决定模组的去留。

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

## 本地检查

Python 3.11+，不依赖第三方 Python 包：

```powershell
python tools/verify_pack.py --allow-incomplete  # 检查现有文件和索引，不代表可发布
python tools/verify_pack.py                     # 严格检查索引、哈希和下载源完整性
python -m unittest discover -s tools -p "test_*.py"
```

`tools/import_test.py --source <实例目录>` 按已核对的审计锁导入，不下载模组、不修改实例、不自动删除仓库文件。
再次导入前先审阅源文件变化并更新锁；删除/排除已有文件需显式审核，校验器会拒绝未纳入索引的文件。
`tools/import-report.json` 列出所有导入、排除与未匹配项。

## 模组与索引

模组使用 packwiz `.pw.toml`，记录名称、目标文件名、安装侧、真实下载来源和内容哈希。
安装侧使用 `client`、`server` 或 `both`
文件变动后在 `pack/` 内运行 `packwiz refresh` 更新索引及 pack.toml 中的索引哈希。
`pack/config` 不是运行实例 config 的全量副本；个人偏好、凭据与缓存不导入。
部署模板不纳入 pack 索引，且不会自动覆盖正式服配置。

## Hotai 版本化

- `pack/hotai/<内部类路径>.badiff` 可作为受控文件直接提交，由 index.toml 记录哈希。
- 外部托管补丁可用 `pack/hotai/<内部类路径>.pw.toml`，其 filename 指向同目录下的 `.badiff`，并填写安装侧、固定下载地址和哈希。
- 这两种方式对同一个补丁只选一种，不重复分发。
- `.class` 是编写/转换阶段的完整类替换；稳定发布优先使用经过 Hotai 转换、测试的 `.badiff`。
- 在 `tools/hotai/` 维护补丁制作说明或生成脚本，记录目标模组 ID/版本、原始 JAR SHA256、目标类、补丁哈希、安装侧、测试结果。这些约束不是 packwiz 自动验证项，后续校验工具需明确检查。
- 不给全局 `.class`/`.badiff` 忽略规则，避免受控补丁被漏掉；构建临时文件仍放在被忽略的 build/ 下。
- 不为当前已禁用的模组自动启用旧补丁；原模组升级后必须重新验证补丁。

格式参考：https://packwiz.infra.link/reference/pack-format/pack-toml/
