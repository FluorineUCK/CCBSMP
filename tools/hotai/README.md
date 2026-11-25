# Hotai 源形式和运行产物

所有纳入项目的补丁必须保留完整、修改后的 `.class`；已经产生的 `.badiff` 也必须保留。`.class` 是可供反编译的 JVM 字节码，不是 Java 源码；对应 Java/ASM 修改器也保留用于审阅和重建。

## 存放规则

- `tools/hotai/artifacts/<类内部路径>.class`：永久保存修改后的完整类。
- `tools/hotai/artifacts/<类内部路径>.badiff`：已产生且核验过的差分。
- `tools/hotai/moreculling/`、`tools/hotai/ragdoll/`：Java 修改器及已有测试/构建脚本。
- `pack/hotai/`：当前 Test 的实际运行输入，每个类只放一种形式。不要把 artifacts 整目录复制进运行 hotai。
- `patches.lock.json`：目标 JAR、安装侧、运行输入、class_source/diff_source 路径与各自 SHA256。

Hotai 会将运行目录的 `.class` 转为 `.badiff` 并删除该 `.class`，因此档案放在 `pack/` 之外，不随游戏启动丢失，也不会重复应用同一个类的两种补丁。

## 当前状态

| 补丁 | 完整 class | 已有 badiff | 运行输入 | 状态 |
|---|---|---|---|---|
| MoreCulling / BlockStateBase_cullShapeMixin | 已归档 | 已归档 | class | 目标仍禁用，仅客户端 |
| Sable Ragdolls / MobRagdollSourceRecovery | 已归档 | 已归档 | badiff | both，保留已有有限启动验证说明 |

2026-11-25 使用 `VerifyArtifacts.java`，从对应精确哈希 JAR 读取目标类、按 Hotai 的 ASM 序列化规范化后回放 `.badiff`；两套结果均与归档 `.class` **逐字节一致**。这不是新一轮游戏运行测试。

`verify_pack.py` 检查完整 class 不缺失、档案哈希和运行输入一致；`import_test.py` 保留档案引用，不用转换后的 badiff 覆盖完整类记录。新补丁或目标 JAR 变化必须重新审核，不能沿用旧验证结果。

客户端补丁不得直接套用到服务端；构建仍需依据安装侧与 target_enabled 筛选。
