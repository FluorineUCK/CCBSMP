# 正式服混合认证 / 白名单

部署基线：Minecraft 1.21.1、NeoForge 21.1.265、DirectAuth 1.3.2、SkinRestorer 2.11.1。
不属于客户端整合包；版本来源与哈希见 `version.lock.json`。

## 账号衔接

- 正式服原先 `online-mode=true`，有 8 个实际存档对应的正版账号。
- 首次部署前完成停服全量运行文件备份，并核对 usercache 与 8 个 playerdata UUID 一一对应。
- 在全新生产 DirectAuth 数据库中仅预置这些已有账号：`isPremium=1`，`onlineUUID=playerUUID=原正版 UUID`。
- 不移动或重命名 playerdata、FTB 团队/任务、进度、统计或模组存档。原 OP UUID 保持不变。
- 密码字段使用随机丢弃密码的 PBKDF2 哈希，无共享密码；老账号必须使用有效微软会话，正常入服不需 `/register` 或 `/login`。
- 如老账号以后确需改为离线登录，须单独核验身份、备份并设置新密码，不能只移除正版标记。
- 新增名单去重后为 7 个未注册账号，按用户提供的精确大小写计算离线 UUID。首次由玩家 `/register`（8–32 字符），之后 `/login`。
- 新玩家如有正版，会在认证后执行 `/online 密码`，按提示确认并重连；保持该账号首次进入时使用的 UUID。
- 总白名单 15 人；名单、实际 UUID、认证数据库只保存在受限运行目录和本地运维输出，不进 Git。

## 配置模板

- `DirectAuth-config.example.json` → `world/serverconfig/DirectAuth-config.json`。
- `skinrestorer-config.example.json` → `config/skinrestorer/config.json`。
- `../server.properties.example` 只列公开项；不能在未安装 DirectAuth、未迁移账号记录时单独套用。
- 白名单、认证模式相关的变更必须停服处理；保持 `white-list=true`、`enforce-whitelist=true`。
- `sessionGracePeriod=0`，避免把重连会话恢复误认为正版验证；不向客户端分发认证模组或数据库。

## 验证与回滚

- 本地 v1 实测：AutoModpack 首装/增删改、可编辑配置保留；离线注册/登录/错误密码；白名单；皮肤与重启持久化；正版人工验收。
- 正式服协议验证：已有正版账号收到 `shouldAuthenticate=true` 的认证握手；新增白名单离线账号通过登录阶段；未列入白名单账号被拒绝。探测在进入世界前断开。
- 公网 AutoModpack TLS 指纹与原始身份一致，285 个发布文件索引逐项核对。
- 正式服启用后的背包/任务/队伍真人验收单独记录，不能把协议探测等同于游戏内验收。
- 2026-11-25 17:01（UTC−4）：正式服记录 FluorineUCK 实际入服，仍使用原正版 UUID（具体标识仅保留在受限验收记录）；客户端记录 `Automatically authenticated (Online Mode)`。用户反馈网络恢复后看起来没有问题。此项已不再仅是协议探测；背包/任务的逐项比较未由助手独立执行。
- 停服备份位于 `C:/Users/Administrator/Desktop/CCBSMP/auth-backup-20261126-042818/`，955 个文件、742222171 字节、逐文件 SHA256 无错误；不重复备份历史 backup/stage 目录和旧 .mdmp 转储。
- 生产服务端仍为原 98 个 JAR 加两个服务器管理 JAR；未推送 Test/v1.1 候选模组。
- 如需回滚：先停服并备份上线后的新增数据，再按部署清单恢复原认证配置/白名单和分发目录、移出本次两个新增 JAR。不要用旧世界直接覆盖玩家上线后的进度。
- 认证数据库、RCON 凭据、TLS 私钥不进 Git、mrpack 或 AutoModpack 的 host-modpack。

## 异常重启记录

首次启动期间 Windows 发生异常重启，系统事件为 Kernel-Power 41 / EventLog 6008，用户确认没有手动重启；根因未确定。
备份完整、模组与玩家数据哈希未变；OP/封禁列表被清零，level.dat 和 level.dat_old 变化。保留异常文件后，从停服备份恢复这五个文件并移除损坏 PID 标记。
第二次启动成功，恢复后启动与公网验证有独立证据。不把重试成功解释为异常重启原因已修复。

证据目录：`D:/CCBSMP/outputs/production-auth/`。
