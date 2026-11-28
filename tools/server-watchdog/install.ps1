param([string]$ServerRoot='C:\Users\Administrator\Desktop\CCBSMP')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$taskName='CCBSMP-Watchdog'
$target=Join-Path $ServerRoot 'watchdog'
if(Test-Path -LiteralPath $target){throw "Target already exists; review/backup it before upgrading: $target"}
if(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue){throw 'Task already exists; refusing to overwrite'}
if(-not (Test-Path -LiteralPath (Join-Path $ServerRoot 'server.properties'))){throw 'Invalid server directory'}
$files=@('watchdog.ps1','policy.ps1','config.example.json','README.md','pause-monitor.cmd','resume-monitor.cmd','reset-failures.cmd','status.cmd')
foreach($f in $files){if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot $f))){throw "Missing artifact: $f"}}
New-Item -ItemType Directory -Path $target|Out-Null
foreach($f in $files){
    $src=Join-Path $PSScriptRoot $f;$dst=Join-Path $target $f
    Copy-Item -LiteralPath $src -Destination $dst
    if((Get-FileHash $src).Hash -ne (Get-FileHash $dst).Hash){throw "Hash mismatch: $f"}
}
$config=Get-Content "$target\config.example.json" -Raw|ConvertFrom-Json
$config.ServerRoot=$ServerRoot
foreach($p in @($config.JavaExe,(Join-Path $ServerRoot $config.JvmArgsFile),(Join-Path $ServerRoot $config.ForgeArgsFile))) {
    if(-not (Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing launch path: $p"}
}
$config|ConvertTo-Json|Set-Content "$target\config.json" -Encoding UTF8
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$target\watchdog.ps1" -Action Initialize
if($LASTEXITCODE -ne 0){throw 'State initialization failed'}
$probeText=& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$target\watchdog.ps1" -Action Probe
if($LASTEXITCODE -ne 0){throw 'Read-only process probe failed'}
$probe=$probeText|ConvertFrom-Json
if($probe.Kind -eq 'Unknown'){throw 'Process identity is uncertain; do not register task'}
$probeText|Write-Output
$exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$action=New-ScheduledTaskAction -Execute $exe -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$target+'\watchdog.ps1" -Action Check') -WorkingDirectory $target
$trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds($config.CheckIntervalSeconds) -RepetitionInterval (New-TimeSpan -Seconds $config.CheckIntervalSeconds)
$principal=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Seconds 45) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'CCBSMP process watchdog; 60s checks, 5min success, 3 failed restarts in 15min latch. Pause before maintenance.'|Out-Null
Disable-ScheduledTask -TaskName $taskName|Out-Null
Export-ScheduledTask -TaskName $taskName|Set-Content "$target\task.xml" -Encoding Unicode
Write-Output 'Installed PAUSED with task DISABLED. Verify then explicitly enable/resume.'
