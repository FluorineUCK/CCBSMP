param([string]$ServerRoot='C:\Users\Administrator\Desktop\CCBSMP')
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$target=Join-Path $ServerRoot 'backup'
$names=@('CCBSMP-WorldBackup','CCBSMP-WorldBackup-Recover')
if(Test-Path -LiteralPath $target){throw 'Backup scripts directory already exists; review before upgrading'}
foreach($name in $names){if(Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue){throw "Task already exists: $name"}}
$config=Get-Content "$PSScriptRoot\config.example.json" -Raw|ConvertFrom-Json
$config.ServerRoot=$ServerRoot
if(-not(Test-Path -LiteralPath $config.WatchdogScript -PathType Leaf)){throw 'Missing process identity probe'}
if(-not(Test-Path -LiteralPath (Join-Path $ServerRoot ($config.WorldDirectory+'\level.dat')))){throw 'Missing world level.dat'}
New-Item -ItemType Directory -Path $target|Out-Null
foreach($file in @('backup.ps1','files.ps1','snapshot.ps1','Rcon.cs','config.example.json','README.md','backup-now.cmd','restore-saving.cmd','status.cmd')){
    $src=Join-Path $PSScriptRoot $file;$dst=Join-Path $target $file
    Copy-Item -LiteralPath $src -Destination $dst
    if((Get-FileHash -LiteralPath $src).Hash -ne (Get-FileHash -LiteralPath $dst).Hash){throw "Copied hash mismatch: $file"}
}
$config|ConvertTo-Json|Set-Content "$target\config.json" -Encoding UTF8
$exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$principal=New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
# Do not forcibly kill the worker in the save-off phase; copy and network operations have internal timeouts.
$settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
foreach($name in $names){
    $mode=if($name -eq 'CCBSMP-WorldBackup'){'Run'}else{'Recover'}
    $interval=if($mode -eq 'Run'){[int]$config.IntervalMinutes}else{1}
    $action=New-ScheduledTaskAction -Execute $exe -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$target+'\backup.ps1" -Action '+$mode) -WorkingDirectory $target
    $trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($interval) -RepetitionInterval (New-TimeSpan -Minutes $interval)
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description ('CCBSMP world backup '+$mode+'; restore automatic saving after failures; no game shutdown')|Out-Null
    Disable-ScheduledTask -TaskName $name|Out-Null
    Export-ScheduledTask -TaskName $name|Set-Content (Join-Path $target ($name+'.xml')) -Encoding Unicode
}
Write-Output 'Installed disabled. First validate recovery, then run/verify first full backup before enabling hourly schedule.'
