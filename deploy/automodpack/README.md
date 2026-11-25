# AutoModpack 正式分发（4.0.7）

本目录保存无凭据模板，不属于客户端 pack 文件集。
版本和下载哈希见 `version.lock.json`，MC 1.21.1 / NeoForge 21.1.265。

## 当前状态：2026-11-25 v1 正式发布

- 正式服 `i702.mczbc.cn:44629`，分发包名 `CCBSMP`。
- 已从验证过的 v1 归档构建 285 个分发文件，含 113 个外层模组 JAR；远端索引 SHA1 全部通过。
- **不是当前 `pack/` 的 Test/v1.1 候选内容**；不要以仓库候选模组列表直接覆盖本次 v1。
- 仍为受控 `host-modpack/main/` 分发、`syncedFiles=[]`，不自动打包运行服配置或世界。
- `requireAutoModpackOnClient=false`：允许原 v1 客户端过渡使用，不强制接管玩家原实例。
- 新入口：`D:/CCBSMP/outputs/production-auth/CCBSMP-AutoModpack.mrpack`，已预置服务器名 `CCBSMP` 和正式服地址。
- DirectAuth、SkinRestorer 仅安装在服务端，不在分发目录中。认证部署说明见 `../auth/README.md`。
- 保留原 TLS 身份，公开指纹未变；公网 AMOK / TLS 1.3 握手已通过。
- 本地实测首次下载、增删改同步、个人配置保留；公网发布索引及通道已核对，正式服真实账号验收单独记录。
- 完整运行备份：`C:/Users/Administrator/Desktop/CCBSMP/auth-backup-20261126-042818/`（名称为远端 UTC+8 时间）。

以下保留基础接入阶段的操作背景；“未发布”的描述只对应当时状态。

## 历史：基础接入阶段布置

- 服务端模组：`mods/automodpack-mc1.21.1-neoforge-4.0.7.jar`。
- 配置：`automodpack/automodpack-server.json`。
- 分发源：`automodpack/host-modpack/main/`；此目录内的文件会全部进入分发索引。
- 验证标记：`automodpack/host-modpack/main/ccbsmp/channel.json`。
- 生成索引：`automodpack/host-modpack/automodpack-content.json`，不要手工修改。
- 复用游戏 TCP 端口 44629；不占用 RCON 29320，不新增端口。
- `syncedFiles=[]`：不自动抓取服务器 mods、config、世界或认证数据库。
- 不要求旧玩家安装，不提示旧玩家，不改变原有登录认证或白名单。
- TLS 与下载密钥校验开启，模组自更新关闭。
- 不覆盖玩家配置，不要求删除现有客户端文件。

## 客户端入口

本地输出：`D:/CCBSMP/outputs/automodpack-setup/CCBSMP-AutoModpack-Bootstrap.mrpack`。
在支持 Modrinth 格式的启动器中导入为**新实例**；内含匹配的加载器依赖、AutoModpack 和预置服务器地址。
这个包用于验证连接和下载，不包含尚未确定的游戏模组，当前不能代替完整整合包游玩。
不要导入覆盖 `CCBSMP Test`，也不要现在要求所有玩家迁移。

首次连接出现证书确认时，与服务器管理员通过独立渠道提供的指纹核对。
管理员在游戏内或 RCON 使用 `automodpack host fingerprint` 读取指纹；不要分发私钥。

## 模组单确定之后

1. 从已审核版本锁构建完整客户端目录，先在独立实例验证。
2. 停服备份现有分发目录及 AutoModpack 身份文件，定点部署服务端变更。
3. 将审核后的客户端文件集放入 `host-modpack/main/`，不从 Test 整目录复制。
4. 运行 `automodpack generate`，审核生成索引：只包含拟分发的模组、受控配置、资源和补丁。
5. 测试首装、更新、移除文件、玩家个人设置保留及回滚；通过后才宣布发布。

`automodpack config reload` 重载配置，`automodpack host` 查看状态，
`automodpack host stop` 临时停止分发；模组 JAR 安装/更新仍需重启。

## 回滚与保密

本次远端备份：`C:/Users/Administrator/Desktop/CCBSMP/automodpack-backup-20261126-031611/`。
备份名使用远端系统时钟；不代表用户所在地日期。
回滚时先停服，再移出本次 AutoModpack JAR；保留 `automodpack/` 作为备份即可。
不要删除原模组、修改世界或重新生成证书来执行回滚。

证书私钥、下载密钥、客户端已知主机/已安装实例记录不进入 Git 或客户端发布内容。
服务器身份位于 `automodpack/.private/`；换机时应作为受限运维资料单独备份迁移，不放入 `host-modpack/main/`。
本次已验证的证书 SHA256 指纹：
`3e582d85dea219778ecb6843ef33a625fbf55a0a41eef2b978576ad0b5ac0d71`。
以上配置以 [v4.0.7 源码](https://github.com/Skidamek/AutoModpack/tree/v4.0.7) 为准，不能套用 5.x 的配置字段。
