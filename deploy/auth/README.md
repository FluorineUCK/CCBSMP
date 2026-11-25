
# 正式服混合认证 / 白名单

部署基线：Minecraft 1.21.1、NeoForge 21.1.265、DirectAuth 1.3.2、SkinRestorer 2.11.1。

## 账号衔接

- 在全新生产 DirectAuth 数据库中仅预置这些已有账号：`isPremium=1`，`onlineUUID=playerUUID=原正版 UUID`。
- 不移动或重命名 playerdata、FTB 团队/任务、进度、统计或模组存档。原 OP UUID 保持不变。
- 密码字段使用随机丢弃密码的 PBKDF2 哈希，无共享密码；老账号必须使用有效微软会话，正常入服不需 `/register` 或 `/login`。
- 如老账号以后确需改为离线登录，须单独核验身份、备份并设置新密码，不能只移除正版标记。
- 新增名单去重后为 7 个未注册账号，按用户提供的精确大小写计算离线 UUID。首次由玩家 `/register`（8–32 字符），之后 `/login`。
- 新玩家如有正版，会在认证后执行 `/online 密码`，按提示确认并重连；保持该账号首次进入时使用的 UUID。

## 配置模板

- `DirectAuth-config.example.json` → `world/serverconfig/DirectAuth-config.json`。
- `skinrestorer-config.example.json` → `config/skinrestorer/config.json`。
- `../server.properties.example` 只列公开项；不能在未安装 DirectAuth、未迁移账号记录时单独套用。
- 白名单、认证模式相关的变更必须停服处理；保持 `white-list=true`、`enforce-whitelist=true`。
- `sessionGracePeriod=0`，避免把重连会话恢复误认为正版验证；不向客户端分发认证模组或数据库。
