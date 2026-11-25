# 更新记录

## 未发布 — 1.1.0-rc.1

### 仓库结构
- 改为 packwiz 风格的 pack/、deploy/、tools/ 布局。
- 新增 pack.toml 与空 index.toml，固定 Minecraft 1.21.1 和 NeoForge 21.1.265。
- Hotai 补丁与模组一样纳入路径、哈希和安装侧管理，实际补丁尚未导入。
- 增加无凭据 server.properties 模板及 AutoModpack 模板目录。
- 移除原有空 overrides/、defaults/、patches/、scripts/、docs/ 骨架。

本记录只描述源码仓库变化，不表示 Test 或正式服务器内容已发布。

### Test 内容导入
- 按现状记录 128 个启用 JAR，127 个通过 Modrinth 哈希或已有/新核对的官方发布文件生成引用。
- 导入 171 个配置、脚本和 Hotai 文件；排除 40 个个人/缓存/备份/禁用配置。
- 不提交第三方 JAR；Vanillin local.starlight 保留待匹配记录，默认发布校验阻止不完整发布。
- 增加文件索引、哈希、安装侧、补丁哈希校验及只读回归测试。

### 移除 Vanillin local.starlight
- 按用户要求从 Test 启用目录及当前审计锁移除该构建，仓库外保留原文件备份，不自动安装原版替代。
- 当前为 127 个启用 JAR，127 个下载引用；此前待匹配项已消除。
- 已有 mrpack/服务端 ZIP 是历史产物，尚未重新构建，不代表当前仓库状态。

- ModernFix 同样明确排除；检查时已不在 Test 和当前 pack 中，没有重复执行删除。
