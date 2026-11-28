# CCBSMP 进程监控

远端目录：`C:\Users\Administrator\Desktop\CCBSMP\watchdog`。
计划任务：`CCBSMP-Watchdog`，SYSTEM 身份每 60 秒检查一次，不依赖 SSH 或桌面会话。

## 判断规则

- 只监控进程是否存活，不以 RCON、网络超时或日志是否更新来杀进程。Java 卡死仍由 Minecraft 的原有 watchdog 处理。
- 当前手动启动的服务端，通过 44629 监听端口的拥有者和 NeoForge 命令行识别；自动启动的实例通过绝对参数文件路径识别。
- 进程不在时，持久化启动意图，再通过 WMI 分离启动 Java。使用现有 `user_jvm_args.txt`，不调整内存。Java 不属于一分钟检查任务的进程树，检查任务超时不会杀游戏。
- 同一实例连续存活至少 300 秒，并被监控观察到，视为自动重启成功；清空连续失败计数。
- 自动启动后在成功判定前退出，计一次失败。未启动出进程的请求有 120 秒宽限，随后计失败。
- 失败以检测时间计入滚动 900 秒窗口，连续失败达到 3 次即锁定，不再发起第四次重启。锁定不会随时间、监控进程退出或机器重启而自动解除。
- 监控缺失/损坏状态、查询失败、端口被别的进程占用、存在身份不明的启动中 Java 时，只记录错误或等待，不启动第二个服务器。
- 进程身份使用 PID + 创建时间，不会把 PID 重用当成原实例。

## 日常操作（在远端执行）

可直接双击此文件夹中的 CMD：

| 文件 | 用途 |
|---|---|
| `pause-monitor.cmd` | 暂停自动重启；**手动停服或更新前先执行**。不会停止当前游戏。 |
| `resume-monitor.cmd` | 恢复检查；若已锁定，不解除锁定。 |
| `reset-failures.cmd` | 明确解除失败锁定、清空计数；保留暂停状态。 |
| `status.cmd` | 显示当前状态与进程识别结果。 |

这些控制操作不会立即启动或停止 Minecraft；恢复后最多约一分钟执行下一次检查。
维护结束可先手动启动服务器，再恢复监控；也可以恢复后由监控在进程不存在时启动。
锁定后修复问题，再运行 `reset-failures.cmd`；如果之前暂停了，还需要 `resume-monitor.cmd`。
**只执行游戏 `/stop` 而不暂停监控，服务器会被自动拉起。**

PowerShell 等效命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\Desktop\CCBSMP\watchdog\watchdog.ps1" -Action Status
```

将 `Status` 改为 `Pause`、`Resume` 或 `Reset`。`Launch` 是内部操作，不要手动调用。

## 文件与排查

- `config.json`：阈值、路径和端口，纯配置，无凭据。
- `state.json`：暂停、锁定、失败时间戳和待验证启动，原子写入；不要通过删除它来复位。
- `watchdog.jsonl`：UTC 时间记录每次检查、启动、失败与锁定；5 MiB 轮换，保留一份 `.1`。
- `launch-logs\*.out.log` / `*.err.log`：每次自动启动的控制台输出。Minecraft 自身日志仍在服务器的 `logs` 目录。
- `task.xml`：安装时的任务定义备份。
- `server.pid`：自动启动时更新，原有启动脚本与 `CCBSMP-Server` 任务不修改。

卸载先暂停，再禁用或删除 `CCBSMP-Watchdog` 任务；不会停止运行中的服务器。

## 测试

`test-policy.ps1` 用可控时间验证 5 分钟、15 分钟、3 次失败、持久化、身份变化和暂停等边界。
`test-integration.ps1` 启动独立低内存 Java 测试进程，验证真实进程退出与重启。仅关闭命令行包含唯一测试目录的测试进程。
测试中使用缩短的成功判定时间；正式配置始终为 300 / 900 秒、3 次、60 秒检查。
部署验证不主动关闭正式服，不声称完成了正式服崩溃重启演练。
