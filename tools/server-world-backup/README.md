# CCBSMP 每小时世界备份

- **最新世界副本**：远端 `D:\CCBSMP-backup\world`，成功后覆盖，仅保留一份。
- **脚本**：远端 `C:\Users\Administrator\Desktop\CCBSMP\backup`。
- **计划任务**：`CCBSMP-WorldBackup`，SYSTEM 每 60 分钟执行；与 SSH 连接、用户登录无关。
- **恢复任务**：`CCBSMP-WorldBackup-Recover` 每分钟检查遗留的恢复保存/临时快照标记；没有标记时不发送命令、不复制文件。仅在备份锁已释放时恢复 `save-on` 或清理本任务自己的快照。

## 一次备份的步骤

1. 检查 D 盘空间、源/目标路径、进程身份，阻止任务重叠。
2. 在线时执行 `save-off` → `save-all flush` 并确认响应。离线时直接复制。
3. 创建短时 Windows VSS 卷快照，立即恢复 `save-on`。从只读快照中的 `world` 复制到 `D:\CCBSMP-backup\world.incoming`，排除运行时锁 `session.lock`（启动时会重建）。拒绝源世界中的符号链接/目录联接。
4. 对每个文件核对快照源和副本的 SHA256、大小、文件总数；若校验不符或服务器在过程中重启，拒绝发布本次副本。
5. 在 `finally` 中确保恢复 `save-on`，并删除本任务创建的特定临时快照。失败时保留恢复标记，由恢复任务重试，旧备份不替换。不删除系统原有的其他快照。
6. 将原 `world` 临时改名 `world.previous`，将校验成功的临时副本改名 `world`，最后删除旧副本。中途失败可恢复旧目录。

不中断游戏，不修改服务器内存、模组、白名单或自动重启设置。正常情况下 D 盘只保留一份世界；复制期间临时需要两份空间。
备份范围是 **world 文件夹**（含各维度、玩家数据和其中的模组世界数据），不是整个服务端；根目录的认证数据库、白名单、配置和模组不在此任务范围内。

## 查看及手动运行

在远端脚本目录双击：

- `backup-now.cmd`：立即执行一次相同备份；已有任务运行则跳过。
- `status.cmd`：显示最近成功备份时间、文件数、大小和恢复保存标记状态。
- `restore-saving.cmd`：手动执行 `save-on` 并确认；正常备份会自动做这一步。

暂停定时备份：在任务计划程序中禁用 `CCBSMP-WorldBackup`。保持恢复任务启用，直到没有 `restore-required.json`。

## 记录及配置

- `D:\CCBSMP-backup\latest.json`：最近成功备份摘要（UTC）。
- `D:\CCBSMP-backup\manifest.json`：最新副本的 SHA256 清单。
- 脚本目录 `backup.jsonl`：刷盘、恢复保存、成功/失败日志；5 MiB 轮换一份。
- `robocopy-latest.log`：最近复制过程。
- `restore-required.json`：未确认恢复自动保存时的持久标记，不要直接删除来掩盖错误。
- `snapshot-owned.json`：本任务创建的临时 VSS 快照 ID 和设备路径，清理仅针对该快照。
- `config.json`：路径、复制/刷盘超时、空间预留、备份周期等，无密码。RCON 密码运行时从本机 `server.properties` 读取，不输出、不复制进备份配置。

复制超时默认 300 秒，冻结/校验时间预算 600 秒，恢复保存最多连续尝试 3 次。修改 `IntervalMinutes` 后需要相应调整计划任务触发器。

首次直接复制实测发现 `save-off` 后实体区块仍会写入，因此正式配置 `UseVss=true`，不会在快照失败时悄悄降级为在线直接复制。VSS 提供同一时点的磁盘视图；仍需 `save-all flush` 将游戏数据刷盘，不等同于所有第三方模组数据库的应用级事务备份。恢复备份时先暂停自动重启监控并停服。

## 测试

`test-files.ps1`：路径边界、覆盖、旧副本保留、被中断的发布恢复、锁文件排除、哈希不一致拒绝。
`test-worker.py`：独立测试世界 + 本地假 RCON，执行真实 robocopy，验证成功及刷盘失败/进程变化时的恢复和旧副本保留。不连接游戏服务器。
