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

## 2026-11-28 同步基线

- 客户端以 `CCBSMP v1.1 Hotfix 1` 为准；正式服只读核对，不在这次 Git 同步中部署或重启。
- `pack/mods` 是客户端与服务端的联合清单，按 `side` 筛选。ModernFix、Lithium 和 Fuck Sable 当前仅服务端；认证模组继续由 `deploy/auth/version.lock.json` 管理。
- `deploy/production-mods.lock.json` 记录正式服实际 JAR 文件名/SHA256；`deploy/user_jvm_args.example.txt` 是无凭据启动参数示例。
- AutoModpack 已停用；`deploy/automodpack` 仅保留历史模板，不用于当前部署或分发。
- 矿石开掘从当前清单移除。Hotai 现有补丁、完整 class、badiff 与制作源码保留；不因客户端暂未安装某补丁而删掉项目中的修复。
- `tools/import_test.py` 是严格快照导入器，旧 Test 不再是当前联合清单的权威来源；不要直接运行它覆盖这次合并基线。

### OE 规则位置

统一在以下位置维护 JSON 规则（OEB 暂无已提供规则）：

```text
pack/kubejs/data/oei/replacements/*.json
pack/kubejs/data/oef/replacements/*.json
pack/kubejs/data/oeb/replacements/*.json
```

根目录 `oei/`、`oef/`、`oeb/` 的 `*_global_replacement_cache.dat` 是运行时缓存，已从索引和导入目录中移除，**不搬进 KubeJS 数据包**。模组的 `pack/config/oe*` 配置仍保留。正式服现有 13 个 OEI 规则、2 个 OEF 规则与配方脚本已纳入仓库。

### 服务端维护

- `tools/server-watchdog/`：每分钟检查进程，15 分钟内连续 3 次启动失败后锁定。
- `tools/server-world-backup/`：每小时 VSS 世界快照、哈希校验、覆盖最新备份；默认目标在远端 D 盘。
- Minecraft 看门狗 150 秒；堆内存示例 `-Xms2G -Xmx10G`。
- 已知限制：外部看门狗只检测进程，游戏主线程退出但 Java 非 daemon 线程残留时可能漏判。此次仅同步现有实现，不宣称修复。
- 已知客户端问题：2026-11-28 启动发生 `create:cardboard_helmet` 客户端扩展重复注册；此次版本管理同步不代表该崩溃已修复或整包回归通过。

## 致谢

感谢 [YunXian_LI（@YunXianLI338）](https://github.com/YunXianLI338) 为 CCBSMP 提供两个 KubeJS JavaScript 脚本，帮助完善整合包。
