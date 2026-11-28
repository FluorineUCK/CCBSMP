# 更新记录

## 2026-11-28 — Hotfix 1 / 正式服改动归档

- 同步客户端受控配置、现有柴油动力配方、MSF Hotai 修复及 class/badiff/制作源码。
- 移除矿石开掘引用；Fuck Sable 改为仅服务端，新增服务端 ModernFix 5.27.27、Lithium 0.15.4 引用。
- 导入正式服 OEI/OEF 规则与配方脚本；删除三个顶层 OE 缓存目录，今后规则仅在 KubeJS 数据包下维护。
- 纳入现有看门狗、每小时世界备份脚本、无凭据 JVM/看门狗配置示例及正式服模组哈希快照。
- 不提交存档、玩家身份、认证库或密码；不修改运行实例、不部署、不重启。本次不是客户端重复注册崩溃修复。

## 1.1.0 客户端默认配置修正 — 2026-11-25（本地，未部署）

- 修正 Test 导入时误排除 Xaero 界面设置的问题：以 tools/client-defaults.json 明确列出 9 个允许发布的文件，保留右上角小地图布局；不导入地图缓存、路标或未经审核的新文件。
- 新引导包 CCBSMP-v1.1-AutoModpack-defaults.2.mrpack 包含上述默认配置；AutoModpack、资源包和光影仍由启动器按下载清单获取，不内嵌 JAR/ZIP。旧包保留。
- 仓库校验 351 个索引文件通过；项目 12 项测试、引导包 4 项归档测试通过。本次未推送 GitHub、未修改正式服或现有玩家实例，未完成小地图实际游戏画面回归。
- 语言排查：旧引导包在隔离客户端原生截图中主菜单为中文；用户 PCL 实例的 options.txt 为 en_us，覆盖发生环节仍未确定，不能据此声称其语言问题已解决。

## 1.1.0 — 2026-11-25 已部署

- 按 Test 基线部署 v1.1；服务端 116 个 JAR，新增 16 项、升级 4 项，JEI 19.76.1.481 与 MezzConfig 0.7.1 纳入 both。
- 完整本地专用服启动、Hotai 补丁、召唤僵尸和正常保存退出测试通过；正式服加载现有世界并到达 Done，RCON 与 AutoModpack running。
- AutoModpack 受控目录 342 个文件，生成索引 341 个（自动排除 AutoModpack 自身 JAR），逐项 SHA1/大小匹配；客户端共 136 个 JAR，含 AutoModpack。
- 正式服停服备份 1063 个文件，975598326 字节；应用阶段 508 个受保护文件哈希未变。保留世界/认证数据、15 人白名单和原 TLS 身份。
- 新完整 mrpack：CCBSMP-v1.1-20261125.mrpack；默认 zh_cn，预置 CCBSMP / i702.mczbc.cn:44629，包含资源包、光影包及启用的 Hotai 补丁。作者用 class/badiff 档案继续保存在 tools/hotai，不重复作为运行补丁分发。
- 已验证归档完整性和每个内容文件哈希；未在本轮实际启动该完整客户端进行多人交互回归。

## 历史候选准备 — 1.1.0-rc.1

### 2026-11-25：补齐 Hotai 源形式及 OE 目录
- 为当前全部两套 Hotai 补丁保存完整 `.class` 和已有 `.badiff`，位于 tools/hotai/artifacts/；保留 Java 修改器，运行目录不重复加载两种形式。
- 对精确版本 JAR 进行差分回放，两套 badiff 结果均与保留 class 逐字节一致；不新增游戏运行验证结论，不启用 MoreCulling。
- OEI/OEB/OEF 的模组引用和 config 已同步；补入此前遗漏的游戏根目录 oei/、oeb/、oef/，各含当前 Test 的 global_replacement_cache.dat 原样快照，并纳入后续导入和哈希索引。
- 此时三个数据文件各 20 字节，common.json 的 Default_Rules_data / Default_Rules_tag 均为空；仅记录现状，不新建替换规则，不修改正式世界。

### 2026-11-25：按当前 Test 对齐本地候选
- 当前基线为 136 个启用 JAR，全部有精确文件哈希和公开下载引用；相对此前 127 项，新增 12 项、升级 7 项、移除 3 项。
- 升级 OELib 0.3.2、OEI 1.0.10、OEB 1.1.5、OEF 1.1.3、Curios 9.6.1、Create Transit 0.3.0、SophisticatedCore 1.5.43.2504。
- 以 Test 为准移除 ClientSort、Create Cyber Goggles、Create Furniture Seats 引用，不修改 Test，也不自动装回。
- Random Optimization、BEB、MouseTweaks、Swaying Garden 等保持仅客户端；新模组安装侧已记录，不等于专用服务端兼容测试通过。
- 同步 201 个配置/脚本/Hotai 文件，排除 56 个个人、缓存、备份、禁用模组或待人工审查文件。
- 加入 resourcepacks/create_mcGUI_v2.13.0.zip 与 shaderpacks/ComplementaryReimagined_r5.10.zip 的下载元数据、安装路径和哈希；不提交 ZIP，不强制玩家的光影/资源包启用设置。
- 保留 MoreCulling 禁用补丁及 ragdoll 补丁原有目标、安装侧和有限验证说明；修正导入脚本将所有补丁误记为 MoreCulling 的问题，新增/变化的补丁必须先审核。
- 静态校验：339 个索引文件、136 个模组引用、2 个资源引用，未解析下载 0；8 个自动化测试通过。完整整合包运行回归尚未完成。
- 本次只更新本地工作区，未提交、未推送 GitHub、未构建发布包、未部署服务器或更新 AutoModpack 分发内容。

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
