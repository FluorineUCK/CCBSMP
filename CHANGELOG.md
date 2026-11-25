# 更新记录

## 未发布 — 1.1.0-rc.1

### 仓库结构
- 改为 packwiz 风格的 pack/、deploy/、tools/ 布局。
- 新增 pack.toml 与空 index.toml，固定 Minecraft 1.21.1 和 NeoForge 21.1.265。
- Hotai 补丁与模组一样纳入路径、哈希和安装侧管理，实际补丁尚未导入。
- 增加无凭据 server.properties 模板及 AutoModpack 模板目录。
- 移除原有空 overrides/、defaults/、patches/、scripts/、docs/ 骨架。

本记录只描述源码仓库变化，不表示 Test 或正式服务器内容已发布。
