# Hotai 导入状态

保留 Test 中 More Culling 的完整 `.class` 替换，目标模组当前 `.jar.disabled`。
适用对象、原始 JAR 与补丁 SHA256 见 patches.lock.json；未启用目标模组，未执行新启动验证。
客户端补丁不得按普通服务端文件直接套用；服务端构建需读取此处安装侧并排除。
Hotai 启动时可能将 class 转为 badiff；必须在测试通过后重新导入和更新索引，而不是认为转换产物天然等价。
