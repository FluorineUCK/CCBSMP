# MoreSnifferFlowers 创造物品栏槽位修复

## 适用版本与安装

- Minecraft 1.21.1 / MoreSnifferFlowers 6.8 NeoForge / Hotai 2.0。
- 原始 JAR SHA256：`1a84878443b85d9e9623fc59c7fa7fe31562030d669a2adf08780325aeb917b0`。
- **仅客户端**。不需要改服务端或移除 AnvilCraft，不改变存档格式。
- 将 ZIP 内的 `hotai` 文件夹合并到客户端实例根目录，完全退出并重启客户端。
- 路径：`hotai/net/abraxator/moresnifferflowers/mixins/client/CreativeInventoryScreenMixin.badiff`。
- 同类不得同时安装 `.class` 和 `.badiff`；升级目标模组后须重新审核补丁。
- 回滚：删除上述单个 `.badiff`，重启客户端。

本次只生成分发包和纳入项目 pack，**没有安装到本地 CCBSMP Test 或正式实例**。

## 最小改动

本地字节码核实 `skipExtraSlots` 是作用于 `selectTab` 的 `NonNullList.size()` WrapOperation。原始实现：

```java
return original.call(instance) - 2;
```

补丁只删除末尾 `ICONST_2; ISUB`，结果相当于：

```java
return original.call(instance);
```

保留 Operation 调用链、Mixin 注解、父类、构造器和标签页渲染逻辑。不硬编码 60、不依据模组顺序筛选槽位、不通过吞掉越界同步包掩盖问题。保留所有槽位的索引对应关系，让垃圾桶位于背包槽位之后。

服务端 60 个槽位时，原逻辑为 58 个 wrapper + 1 垃圾桶，修复后为 60 + 1。服务端 48 个槽位时则从 46 + 1 修复为 48 + 1。客户端多出的最后一格是创造垃圾桶，并不需要与服务端总槽数相等。

## 构建与测试

在 `D:/CCBSMP` 执行：

```powershell
$mod = (Get-ChildItem 'run/versions/CCBSMP Test/mods' -Filter '*MoreSniffer*.jar').FullName
python project/tools/hotai/msf-creative/build.py --jdk 'C:/Program Files/Java/jdk-21.0.11' --mod $mod --hotai 'run/versions/CCBSMP Test/mods/[绷带] hotai-2.0.jar' --asm-dir run/libraries/org/ow2/asm --out outputs/hotai-msf-creative
```

构建器检查目标 JAR 精确哈希及方法签名，要求恰好找到一处尾部减法。按照 Hotai 的 `ClassNode -> ClassWriter(0)` 规范化基线生成 badiff，并验证差分重建与修改后完整 class 逐字节一致。

验证结果：

- RED：执行原始 handler 的真实指令，48 格被截为 46 个 wrapper，测试按预期失败。
- GREEN：0、2、46、48、60、61、128、256 八组数量均保留；所有服务端合法索引的槽位对象顺序不变，垃圾桶追加在最后。
- Operation 参数仍为原列表、调用恰好一次、尊重上游返回值。
- ASM BasicVerifier、JVM `-Xverify:all`、badiff 回放通过。
- 独立客户端启动确认 Hotai 日志 `Patched class: net/abraxator/moresnifferflowers/mixins/client/CreativeInventoryScreenMixin`，随后仍存活并完成纹理加载。测试进程由脚本终止，不宣称正常游戏退出。

单元测试抽取真实 handler 指令，仅将 NonNullList/Operation 类型映射到测试替身；槽位 wrapper 和垃圾桶关系用列表模拟。最小启动实例只有 MSF、其内嵌依赖和 Hotai，缺少可选 Carry On 的警告不等于补丁失败。

**尚未验证**：真实进入世界打开创造“物品栏”页、AnvilCraft 口袋/硬化嘴效果操作、服务端同步末槽位和多人重连。因此启动通过不等于完整故障场景验收。建议实际测试打开该页后让服务端更新最后槽位，确认不掉线，且物品不被同步到垃圾桶。

产物与启动日志：`D:/CCBSMP/outputs/hotai-msf-creative/`。完整 class 与 badiff 永久保存在 `project/tools/hotai/artifacts/` 对应内部类路径；仅 badiff 进入 pack 分发。
