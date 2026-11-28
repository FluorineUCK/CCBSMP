function New-WorldSnapshot([string]$Source) {
    $volume=[IO.Path]::GetPathRoot($Source)
    if($volume -notmatch '^[A-Za-z]:\\$'){throw 'VSS source must be a local drive'}
    $mount=[IO.Path]::GetFullPath((Join-Path $homeDir 'snapshot-view'))
    if(Get-Item -LiteralPath $mount -Force -ErrorAction SilentlyContinue){throw 'Snapshot mount already exists without cleanup; refusing overwrite'}
    $created=Invoke-CimMethod -ClassName Win32_ShadowCopy -MethodName Create -Arguments @{Volume=$volume;Context='ClientAccessible'} -ErrorAction Stop
    if($created.ReturnValue -ne 0){throw "VSS snapshot creation failed: $($created.ReturnValue)"}
    $shadow=Get-CimInstance Win32_ShadowCopy -Filter ("ID = '"+$created.ShadowID+"'") -ErrorAction Stop
    if($null -eq $shadow){throw 'Created VSS snapshot could not be retrieved'}
    $script:shadowRecord=@{id=[string]$shadow.ID;device=[string]$shadow.DeviceObject;volume=[string]$shadow.VolumeName;mount=$mount;createdUtc=[DateTime]::UtcNow.ToString('o')}
    Save-Json $shadowMarker $script:shadowRecord
    Log 'snapshot-created' $script:shadowRecord
    # robocopy on this host cannot use GLOBALROOT directly. mklink can create the
    # temporary directory link without PowerShell's nonexistent-target rejection.
    if($shadow.DeviceObject -notmatch '^\\\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy[0-9]+$'){throw 'Unexpected snapshot device path'}
    $args='/d /c mklink /d "'+$mount+'" "'+$shadow.DeviceObject+'\"'
    $p=Start-Process -FilePath $env:ComSpec -ArgumentList $args -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $homeDir 'snapshot-mount.log') -RedirectStandardError (Join-Path $homeDir 'snapshot-mount.err')
    if($p.ExitCode -ne 0){throw "Snapshot mount creation failed: $($p.ExitCode)"}
    return (Join-Path $mount $Source.Substring($volume.Length))
}

function Remove-OwnedSnapshot {
    $record=$script:shadowRecord
    if($null -eq $record -and (Test-Path -LiteralPath $shadowMarker)){$record=Get-Content -LiteralPath $shadowMarker -Raw|ConvertFrom-Json}
    if($null -eq $record){return}
    if([string]$record.id -notmatch '^\{[0-9A-Fa-f-]{36}\}$' -or [string]$record.device -notmatch '^\\\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy[0-9]+$'){throw 'Invalid owned snapshot record; refusing cleanup'}
    $mount=[IO.Path]::GetFullPath((Join-Path $homeDir 'snapshot-view'))
    $link=Get-Item -LiteralPath $mount -Force -ErrorAction SilentlyContinue
    if($link){
        if($record.mount -ne $mount -or -not($link.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Unexpected snapshot mount; refusing cleanup'}
        # Non-recursive deletion removes ONLY the owned link, not its target data.
        [IO.Directory]::Delete($mount)
    }
    $snapshot=Get-CimInstance Win32_ShadowCopy -Filter ("ID = '"+$record.id+"'") -ErrorAction Stop
    if($null -ne $snapshot){
        if($snapshot.DeviceObject -ne $record.device -or $snapshot.VolumeName -ne $record.volume){throw 'Snapshot identity mismatch; refusing cleanup'}
        # Deletes ONLY the exact temporary shadow recorded by this backup, never other shadows.
        $snapshot|Remove-CimInstance -ErrorAction Stop
    }
    if(Test-Path -LiteralPath $shadowMarker){Remove-Item -LiteralPath $shadowMarker -ErrorAction Stop}
    Log 'snapshot-removed' @{id=$record.id}
    $script:shadowRecord=$null
}
