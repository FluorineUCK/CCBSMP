[CmdletBinding()]
param(
    [ValidateSet('Check','Status','Pause','Resume','Reset','Initialize','Probe','Launch')]
    [string]$Action='Check',
    [string]$ConfigPath='',
    [double]$RequestTime=0
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if([string]::IsNullOrWhiteSpace($ConfigPath)){$ConfigPath=Join-Path $PSScriptRoot 'config.json'}
# Detached WMI launches may have no console handle.
try {[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)} catch {}
. "$PSScriptRoot\policy.ps1"
$homeDir=Split-Path -Parent ([IO.Path]::GetFullPath($ConfigPath))
$statePath=Join-Path $homeDir 'state.json'
$logPath=Join-Path $homeDir 'watchdog.jsonl'
$lockPath=Join-Path $homeDir 'watchdog.lock'
$utf8=[Text.UTF8Encoding]::new($false)

function Write-AtomicJson($Value, [string]$Path) {
    $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        $bytes=$utf8.GetBytes(($Value|ConvertTo-Json -Depth 12))
        $fs=[IO.File]::Open($temp,'CreateNew','Write','None')
        try {$fs.Write($bytes,0,$bytes.Length);$fs.Flush($true)} finally {$fs.Dispose()}
        if (Test-Path -LiteralPath $Path) {[IO.File]::Replace($temp,$Path,[NullString]::Value)} else {[IO.File]::Move($temp,$Path)}
    } finally {if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp}}
}

function Write-WatchLog([string]$Event,$Detail) {
    if ((Test-Path -LiteralPath $logPath) -and (Get-Item -LiteralPath $logPath).Length -gt $config.LogMaxBytes) {
        $old=$logPath+'.1'
        if(Test-Path -LiteralPath $old){Remove-Item -LiteralPath $old}
        Move-Item -LiteralPath $logPath -Destination $old
    }
    $line=@{utc=[DateTime]::UtcNow.ToString('o');event=$Event;detail=$Detail}|ConvertTo-Json -Depth 8 -Compress
    [IO.File]::AppendAllText($logPath,$line+[Environment]::NewLine,$utf8)
}

function Get-Identity($Proc) {
    return ('{0}:{1}' -f $Proc.ProcessId,([datetime]$Proc.CreationDate).ToUniversalTime().Ticks)
}

function Get-Observation {
    # A failed OS query throws: it must never be interpreted as "server absent".
    $java=@(Get-CimInstance Win32_Process -Filter "Name='java.exe' OR Name='javaw.exe'" -ErrorAction Stop)
    $listeners=@(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object LocalPort -eq $config.GamePort)
    $owners=@($listeners | Select-Object -ExpandProperty OwningProcess | Sort-Object -Unique)
    $relative=([string]$config.ForgeArgsFile).Replace('/','\').ToLowerInvariant()
    $absolute=(Join-Path $config.ServerRoot $config.ForgeArgsFile).Replace('/','\').ToLowerInvariant()
    $scoped=@();$possible=@()
    foreach($proc in $java) {
        if ([string]::IsNullOrWhiteSpace($proc.CommandLine)) {throw "Cannot read Java command line for PID $($proc.ProcessId)"}
        $cmd=([string]$proc.CommandLine).Replace('/','\').ToLowerInvariant()
        if($cmd.Contains($absolute)) {$scoped+=@($proc)}
        elseif($cmd.Contains('@'+$relative)) {$possible+=@($proc)}
    }
    # The current run.bat may use relative @args; identify it by its bound game port.
    $portMatches=@(($scoped+$possible) | Where-Object {$owners -contains $_.ProcessId})
    if($owners.Count -gt 0) {
        if($portMatches.Count -ne 1 -or $owners.Count -ne 1) {return @{Kind='Unknown';Identity=$null;Reason='game-port-conflict'}}
        $main=$portMatches[0]
        # Permit only its launcher ancestors, not a second independent server.
        $ancestors=@();$parent=$main.ParentProcessId
        for($i=0;$i -lt 8;$i++) {
            $p=@($java|Where-Object ProcessId -eq $parent)
            if($p.Count -ne 1){break}
            $ancestors+=@($parent);$parent=$p[0].ParentProcessId
        }
        $other=@($scoped|Where-Object {$_.ProcessId -ne $main.ProcessId -and $ancestors -notcontains $_.ProcessId})
        if($other.Count -gt 0){return @{Kind='Unknown';Identity=$null;Reason='multiple-server-processes'}}
        return @{Kind='Alive';Identity=(Get-Identity $main);ProcessId=$main.ProcessId;Reason='game-port-owner'}
    }
    # Absolute paths identify an auto-launched process even while starting up.
    if($scoped.Count -eq 1){return @{Kind='Alive';Identity=(Get-Identity $scoped[0]);ProcessId=$scoped[0].ProcessId;Reason='absolute-args'}}
    if($scoped.Count -gt 0 -or $possible.Count -gt 0){return @{Kind='Unknown';Identity=$null;Reason='unbound-or-ambiguous-java'}}
    # Never race a manual scheduled launch that has not created Java yet.
    $launchTask=Get-ScheduledTask -TaskName 'CCBSMP-Server' -ErrorAction SilentlyContinue
    if($null -ne $launchTask -and [string]$launchTask.State -eq 'Running') {
        return @{Kind='Unknown';Identity=$null;Reason='manual-launch-task-running'}
    }
    return @{Kind='Absent';Identity=$null;Reason='no-server-process'}
}

$lock=$null
try {
    $config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
    foreach($field in @('SuccessSeconds','FailureWindowSeconds','MaxFailures','LaunchGraceSeconds','LogMaxBytes')) {
        if([double]$config.$field -le 0){throw "Invalid configuration: $field"}
    }
    if(-not [IO.Path]::IsPathRooted($config.ServerRoot) -or -not [IO.Path]::IsPathRooted($config.JavaExe)) {throw 'Absolute server and Java paths required'}
    if($Action -eq 'Probe') {Get-Observation|ConvertTo-Json -Depth 6;exit 0}
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    do {
        try {$lock=[IO.File]::Open($lockPath,'OpenOrCreate','ReadWrite','None')} catch [IO.IOException] {
            if($Action -ne 'Launch' -or [DateTime]::UtcNow -ge $deadline){Write-Output 'Another watchdog operation holds the lock';exit 0}
            Start-Sleep -Milliseconds 250
        }
    } while($null -eq $lock)
    if($Action -eq 'Initialize') {
        if(Test-Path -LiteralPath $statePath){throw 'State already exists; refusing to reset it'}
        $state=New-WatchState;$state.Paused=$true
        Write-AtomicJson $state $statePath
        Write-WatchLog 'initialized-paused' @{}
        $state|ConvertTo-Json -Depth 6;exit 0
    }
    if(-not (Test-Path -LiteralPath $statePath)){throw 'Missing state.json; initialize explicitly (fail closed)'}
    $state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
    if($state.Version -ne 1 -or $state.Paused -isnot [bool] -or $state.Latched -isnot [bool]){throw 'Invalid state schema'}
    # Access required fields before doing anything that could launch a server.
    $null=$state.Failures;$null=$state.Attempt;$null=$state.LastCheck;$null=$state.LastReason
    if($Action -eq 'Status') {
        @{state=$state;observation=(Get-Observation)}|ConvertTo-Json -Depth 8;exit 0
    }
    if($Action -eq 'Launch') {
        # Internal detached launcher: do not attach Java to the repeating task's job.
        # Reject stale launch requests or a request cancelled by Pause/Reset.
        $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if($state.Paused -or $state.Latched -or $null -eq $state.Attempt -or $state.Attempt.Requested -ne $RequestTime -or $now-$RequestTime -ge $config.LaunchGraceSeconds -or $null -ne $state.Attempt.Identity) {
            Write-WatchLog 'stale-launch-ignored' @{request=$RequestTime};exit 0
        }
        $again=Get-Observation
        if($again.Kind -ne 'Absent') {
            $state.Attempt=$null
            Write-AtomicJson $state $statePath
            Write-WatchLog 'launch-cancelled' $again;exit 0
        }
        foreach($path in @($config.JavaExe,(Join-Path $config.ServerRoot $config.JvmArgsFile),(Join-Path $config.ServerRoot $config.ForgeArgsFile))) {
            if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Launch file missing: $path"}
        }
        $stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
        $launchDir=Join-Path $homeDir 'launch-logs'
        [IO.Directory]::CreateDirectory($launchDir)|Out-Null
        $args=@(('"@{0}"' -f (Join-Path $config.ServerRoot $config.JvmArgsFile)),('"@{0}"' -f (Join-Path $config.ServerRoot $config.ForgeArgsFile)),'nogui')
        $p=Start-Process -FilePath $config.JavaExe -ArgumentList $args -WorkingDirectory $config.ServerRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $launchDir "$stamp.out.log") -RedirectStandardError (Join-Path $launchDir "$stamp.err.log") -PassThru
        $proc=Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)"
        if($null -ne $proc) {
            $state.Attempt.Identity=Get-Identity $proc
            $state.Attempt.SeenSince=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        }
        Write-AtomicJson $state $statePath
        [IO.File]::WriteAllText((Join-Path $config.ServerRoot 'server.pid'),[string]$p.Id,[Text.Encoding]::ASCII)
        Write-WatchLog 'launched' @{processId=$p.Id;identity=$state.Attempt.Identity;stdout="$stamp.out.log"}
        exit 0
    }
    if($Action -in @('Pause','Resume','Reset')) {
        switch($Action){
            'Pause' {$state.Paused=$true;$state.Attempt=$null}
            'Resume' {$state.Paused=$false}
            'Reset' {$state.Latched=$false;$state.Failures=@();$state.Attempt=$null}
        }
        $state.LastReason=$Action
        Write-AtomicJson $state $statePath
        Write-WatchLog $Action @{paused=$state.Paused;latched=$state.Latched}
        $state|ConvertTo-Json -Depth 6;exit 0
    }
    $observation=if($state.Paused -or $state.Latched){@{Kind='Unknown';Identity=$null;Reason='monitor-disabled'}}else{Get-Observation}
    $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $result=Step-WatchState $state $observation $now $config
    $state.LastReason=$result.Reason
    Write-AtomicJson $state $statePath
    Write-WatchLog 'check' @{result=$result;observation=$observation;failures=@($state.Failures).Count;latched=$state.Latched}
    if($result.Action -eq 'Start') {
        $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $command='"{0}" -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}" -Action Launch -ConfigPath "{2}" -RequestTime {3}' -f $ps,$PSCommandPath,[IO.Path]::GetFullPath($ConfigPath),$now
        $startup=New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ShowWindow=[uint16]0}
        $created=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine=$command;CurrentDirectory=$homeDir;ProcessStartupInformation=$startup}
        if($created.ReturnValue -ne 0){throw "Detached launcher failed: $($created.ReturnValue)"}
        Write-WatchLog 'launch-dispatched' @{launcherPid=$created.ProcessId;request=$now;command=$command}
    }
    $result|ConvertTo-Json -Compress
} catch {
    $message=$_.Exception.Message
    try {Write-WatchLog 'error-no-restart' @{message=$message}} catch {}
    Write-Error $message -ErrorAction Continue
    exit 1
} finally {if($null -ne $lock){$lock.Dispose()}}
