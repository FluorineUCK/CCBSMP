# Ragdoll recovery 普通实体快速路径

目标：Minecraft 1.21.1 / NeoForge 21.1.265，Sable Ragdolls 0.8.1，Hotai 2.0。

原始 JAR SHA256：`52231de8cf20713040e948ec41c0813d8b1eab2e7ec327c1ff5da8bdc3ba33fd`。

补丁类：`dev/leo/sableplayerragdoll/mob/MobRagdollSourceRecovery`，安装侧 both。

## 改动

只在两个 `active` 重载入口加入 `contains("sable_player_ragdoll_mob_recovery", 10)` 判断。没有 CompoundTag 恢复记录时直接返回 false；实体入口在获取世界时间之前判断。

普通实体仍需一次 `getPersistentData()` 和一次 NBT 键/类型查询，但不再读取世界时间、不再因缺键执行 `getCompound()` 分配空标签、不再进入 Session 判断。有记录时仍执行原版 UUID 匹配和 `now < ExpiresAt`，增加的 contains 检查仅为快速路径代价。未改动 begin/extend/restore/clear、NBT 格式、物理和 AI 行为。

这是报告建议中的“无状态快速返回”，**不是完整的运行时字段/附件缓存改造**。刻意不缓存负结果或 active 值，因此无需维护失效钩子，读档、卸载后重建实体、同 tick 修改 NBT 不会留下缓存。没有新增辅助类，也不修改 Minecraft 基类或 mixin。

## 构建与验证

在 `D:/CCBSMP` 执行（使用本地依赖，不下载）：

```powershell
python project/tools/hotai/ragdoll/build.py --jdk 'C:/Program Files/Java/jdk-21.0.11' --mod 'run/versions/CCBSMP Test/mods/sable_player_ragdoll-1.21.1-0.8.1.jar' --hotai 'run/versions/CCBSMP Test/mods/[绷带] hotai-2.0.jar' --asm-dir run/libraries/org/ow2/asm --out outputs/hotai-ragdoll
```

构建器拒绝不同哈希的目标 JAR；仅插入两个 guard，保留原方法其余字节码。先按 Hotai 的 `ClassNode -> ClassWriter(0)` 规范化基线，再使用其内置 badiff 库生成并回放补丁，不能直接对原始 JAR 类字节生成差分。

自动测试：

- 原始类负向测试确实失败：普通实体 clock=1、getCompound=1。
- 补丁普通实体 clock=0、getCompound=0。
- 两个重载各 2,880 组差分状态：缺键、错误标签类型、空记录、缺失/不匹配 UUID、缺失过期值、边界和极端时间。
- 开始、过期、延长、恢复原 flags、清理、新实体载入记录、外部改 Session、整体替换 persistentData。
- ASM BasicVerifier、JVM `-Xverify:all` 和 badiff 序列化回放。

测试执行真实目标类字节码，Minecraft API 使用可计数测试替身；这不等于真实游戏中的布娃娃完整生命周期验证。

真实启动验证（2026-11-25）：独立临时目录、NeoForge 21.1.265 + Sable 2.0.6 + Ragdolls 0.8.1 + Hotai 2.0，使用分发的 `.badiff`。日志确认 Hotai patched target、服务端 Done、成功召唤僵尸、正常 stop 且退出码 0。日志位于 `D:/CCBSMP/outputs/hotai-ragdoll/smoke-console.log`。最小模组集未安装 Create，Sable 报告其内置物理标签引用缺失 `create:flywheel`；未阻止启动。未进行客户端画面、布娃娃击倒恢复、真实存档重载或完整整合包兼容回归。

## 安装与回滚

分发包仅含 `hotai/dev/leo/sableplayerragdoll/mob/MobRagdollSourceRecovery.badiff`。将 hotai 目录合并至游戏/服务端目录，安装 Hotai 2.0 和上述目标模组版本，然后**完全重启进程**。服务端可独立安装此优化；单人需安装于客户端实例。不要同时放置同类的 `.class` 或其他版本补丁。

启动日志应出现 `Patched class: dev/leo/sableplayerragdoll/mob/MobRagdollSourceRecovery`。回滚只移除这个 `.badiff` 并重启，不需要改存档。

正式效果仍需同场景预热后的 Spark A/B 采样；没有把原报告 2.84% 宣称为实际收益。未修改正式实例、模拟距离或 ServerCore 配置。
