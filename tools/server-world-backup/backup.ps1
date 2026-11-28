[CmdletBinding()]
param([ValidateSet('Run','Status','RestoreSaving','Recover')][string]$Action='Run',[string]$ConfigPath='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
if(-not $ConfigPath){$ConfigPath=Join-Path $PSScriptRoot 'config.json'}
try{[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)}catch{}
. "$PSScriptRoot\files.ps1"
. "$PSScriptRoot\snapshot.ps1"
Add-Type -Path "$PSScriptRoot\Rcon.cs"
$homeDir=Split-Path -Parent ([IO.Path]::GetFullPath($ConfigPath))
$marker=Join-Path $homeDir 'restore-required.json'
$shadowMarker=Join-Path $homeDir 'snapshot-owned.json'
$script:shadowRecord=$null
$utf8=[Text.UTF8Encoding]::new($false)
$lock=$null;$config=$null;$needsRestore=$false;$failure=$null

function Save-Json([string]$Path,$Value) {
    $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try{
        $bytes=$utf8.GetBytes(($Value|ConvertTo-Json -Depth 12))
        $s=[IO.File]::Open($temp,'CreateNew','Write','None')
        try{$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()}
        if(Test-Path -LiteralPath $Path){[IO.File]::Replace($temp,$Path,[NullString]::Value)}else{[IO.File]::Move($temp,$Path)}
    }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp}}
}
function Log([string]$Event,$Detail) {
    $path=Join-Path $homeDir 'backup.jsonl'
    if((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -ge $config.LogMaxBytes){
        if(Test-Path -LiteralPath ($path+'.1')){Remove-Item -LiteralPath ($path+'.1')}
        Move-Item -LiteralPath $path -Destination ($path+'.1')
    }
    $line=@{utc=[DateTime]::UtcNow.ToString('o');event=$Event;detail=$Detail}|ConvertTo-Json -Depth 8 -Compress
    [IO.File]::AppendAllText($path,$line+[Environment]::NewLine,$utf8)
}
function Observe-Server {
    $text=& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $config.WatchdogScript -Action Probe
    if($LASTEXITCODE -ne 0){throw 'Server process probe failed'}
    $obs=$text|ConvertFrom-Json
    if($obs.Kind -notin @('Alive','Absent')){throw ('Uncertain server identity: '+$obs.Reason)}
    return $obs
}
function Command([string]$Text) {
    return [BackupRcon]::Run('127.0.0.1',$rconPort,$password,$Text,([int]$config.RconTimeoutSeconds*1000))
}
function Restore-AutoSave {
    for($i=1;$i -le $config.RestoreAttempts;$i++){
        try{
            $response=Command 'save-on'
            if($response -notmatch 'saving is now enabled|already turned on'){throw 'Unrecognized save-on acknowledgement'}
            Log 'save-on-confirmed' @{response=$response;attempt=$i}
            if(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker}
            return $true
        }catch{
            Log 'save-on-retry' @{attempt=$i;error=$_.Exception.Message}
            if($i -lt $config.RestoreAttempts){Start-Sleep -Seconds 2}
        }
    }
    return $false
}

try{
    $config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
    if($Action -eq 'Status'){
        $latest=Join-Path $config.BackupRoot 'latest.json'
        @{restoreRequired=(Test-Path -LiteralPath $marker);snapshotCleanupRequired=(Test-Path -LiteralPath $shadowMarker);latest=if(Test-Path -LiteralPath $latest){Get-Content $latest -Raw|ConvertFrom-Json}else{$null}}|ConvertTo-Json -Depth 6
        exit 0
    }
    foreach($n in @('RconTimeoutSeconds','CopyTimeoutSeconds','FreezeBudgetSeconds','RestoreAttempts','FreeSpaceReserveBytes','LogMaxBytes')){if([double]$config.$n -le 0){throw "Invalid configuration: $n"}}
    try{$lock=[IO.File]::Open((Join-Path $homeDir 'backup.lock'),'OpenOrCreate','ReadWrite','None')}catch [IO.IOException]{Write-Output 'Backup already running; skipped';exit 0}
    if($Action -eq 'Recover' -and -not(Test-Path -LiteralPath $marker) -and -not(Test-Path -LiteralPath $shadowMarker)){exit 0}
    $properties=@{}
    foreach($line in [IO.File]::ReadAllLines((Join-Path $config.ServerRoot 'server.properties'))){
        if($line -match '^\s*(rcon\.password|rcon\.port|enable-rcon|level-name)\s*[=:]\s*(.*)$'){$properties[$matches[1]]=[BackupRcon]::UnescapeProperty($matches[2])}
    }
    if($properties['enable-rcon'] -ne 'true' -or -not $properties['rcon.password']){throw 'RCON must be enabled for online backups'}
    $password=$properties['rcon.password'];$rconPort=[int]$properties['rcon.port']
    if($Action -in @('RestoreSaving','Recover')){
        if($Action -eq 'RestoreSaving' -or (Test-Path -LiteralPath $marker)){
            if(-not(Restore-AutoSave)){throw 'Could not restore automatic saving; run save-on in server console'}
        }
        Remove-OwnedSnapshot
        Write-Output 'Automatic saving enabled';exit 0
    }
    if(Test-Path -LiteralPath $marker){
        if(-not(Restore-AutoSave)){throw 'Pending save-on recovery failed; refusing new backup'}
    }
    Remove-OwnedSnapshot
    if($properties['level-name'] -ne $config.WorldDirectory){throw 'World directory differs from server.properties'}
    $source=[IO.Path]::GetFullPath((Join-Path $config.ServerRoot $config.WorldDirectory))
    $dest=[IO.Path]::GetFullPath($config.BackupRoot).TrimEnd('\')
    if(-not $source.StartsWith(([IO.Path]::GetFullPath($config.ServerRoot).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Source world escapes server root'}
    if($dest -eq $source -or $dest.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase) -or $source.StartsWith($dest+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Source and destination must not overlap'}
    $incoming=Get-BackupChild $dest 'world.incoming'
    Assert-PlainTree $source
    if(-not(Test-Path -LiteralPath (Join-Path $source 'level.dat') -PathType Leaf)){throw 'Missing source world level.dat'}
    [IO.Directory]::CreateDirectory($dest)|Out-Null
    $size=(Get-ChildItem -LiteralPath $source -File -Force -Recurse|Measure-Object Length -Sum).Sum
    $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($dest))
    if($drive.AvailableFreeSpace -lt $size+$config.FreeSpaceReserveBytes){throw 'Insufficient disk space; previous backup retained'}
    Recover-WorldBackup $dest
    Remove-BackupChild $dest 'world.incoming'
    [IO.Directory]::CreateDirectory($incoming)|Out-Null
    $before=Observe-Server
    $started=[DateTime]::UtcNow
    $deadline=$started.AddSeconds($config.FreezeBudgetSeconds)
    Log 'started' @{source=$source;destination=$dest;process=$before;sourceBytes=$size}
    $verified=$null;$copyCode=$null;$snapshotId=$null;$copySource=$source
    try{
        if($before.Kind -eq 'Alive'){
            # Durable marker is created BEFORE save-off, even if its response is lost.
            Save-Json $marker @{sinceUtc=[DateTime]::UtcNow.ToString('o');identity=$before.Identity}
            $needsRestore=$true
            $off=Command 'save-off'
            if($off -notmatch 'saving is now disabled|already turned off'){throw 'Unrecognized save-off acknowledgement'}
            Log 'save-off-confirmed' @{response=$off}
            $flushed=Command 'save-all flush'
            if($flushed -notmatch 'Saved the game'){throw 'World flush not acknowledged'}
            Log 'save-all-flush-confirmed' @{response=$flushed}
        }
        if($config.UseVss){
            $copySource=New-WorldSnapshot $source
            $snapshotId=$script:shadowRecord.id
            # Snapshot freezes the disk view; resume game saving before copying any files.
            if($needsRestore){
                if(-not(Restore-AutoSave)){throw 'Could not restore saving after creating snapshot'}
                $needsRestore=$false
            }
        }
        $copyLog=Join-Path $homeDir 'robocopy-latest.log'
        $args=@(('"{0}"' -f $copySource),('"{0}"' -f $incoming),'/E','/COPY:DAT','/DCOPY:DAT','/R:1','/W:1','/XJ','/XF','session.lock','/NP','/NFL','/NDL',('"/LOG:{0}"' -f $copyLog))
        $copy=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\robocopy.exe') -ArgumentList $args -WindowStyle Hidden -PassThru
        $remaining=[Math]::Min([double]$config.CopyTimeoutSeconds,($deadline-[DateTime]::UtcNow).TotalSeconds)
        if($remaining -le 0 -or -not $copy.WaitForExit([int]($remaining*1000))){
            if(-not $copy.HasExited){$copy.Kill();$copy.WaitForExit()}
            throw 'World copy timed out; previous backup retained'
        }
        $copy.WaitForExit();$copyCode=$copy.ExitCode
        if($copyCode -ge 8){throw "Robocopy failed with exit code $copyCode; previous backup retained"}
        $expected=Get-WorldManifest $copySource $deadline
        $verified=Get-WorldManifest $incoming $deadline
        Assert-MatchingWorlds $expected $verified
        $after=Observe-Server
        if($after.Kind -ne $before.Kind -or $after.Identity -ne $before.Identity){throw 'Server identity changed during backup; previous backup retained'}
    }catch{$failure=$_.Exception.Message}
    finally{
        if($needsRestore){
            if(Restore-AutoSave){$needsRestore=$false}else{$failure='Automatic saving could not be restored; recovery marker retained; previous backup retained'}
        }
        try{Remove-OwnedSnapshot}catch{$failure='Temporary snapshot cleanup failed; cleanup marker retained: '+$_.Exception.Message}
    }
    if($failure){throw $failure}
    Publish-WorldBackup $dest
    [long]$bytes=0
    foreach($entry in $verified.Values){$bytes+=[long]$entry.bytes}
    $summary=@{completedUtc=[DateTime]::UtcNow.ToString('o');startedUtc=$started.ToString('o');source=$source;destination=(Join-Path $dest 'world');files=$verified.Count;bytes=$bytes;robocopyExit=$copyCode;sha256Verified=$true;autosaveRestored=(-not $needsRestore);processIdentity=$before.Identity;snapshotId=$snapshotId;usedVss=[bool]$config.UseVss;excluded=@('session.lock')}
    Save-Json (Join-Path $dest 'manifest.json') $verified
    Save-Json (Join-Path $dest 'latest.json') $summary
    Log 'completed' $summary
    $summary|ConvertTo-Json -Depth 6
}catch{
    try{Log 'failed' @{error=$_.Exception.Message;restoreRequired=(Test-Path -LiteralPath $marker)}}catch{}
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}finally{
    if($null -ne $lock){$lock.Dispose()}
}
