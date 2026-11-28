function Assert-PlainTree([string]$Path) {
    if(-not(Test-Path -LiteralPath $Path)){return}
    $stack=[Collections.Generic.Stack[string]]::new();$stack.Push($Path)
    while($stack.Count -gt 0){
        $p=$stack.Pop();$item=Get-Item -LiteralPath $p -Force -ErrorAction Stop
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Reparse point not permitted: $p"}
        if($item.PSIsContainer){foreach($child in (Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop)){$stack.Push($child.FullName)}}
    }
}

function Get-BackupChild([string]$Root,[string]$Name) {
    if($Name -notin @('world','world.incoming','world.previous')){throw 'Invalid backup child name'}
    if(-not [IO.Path]::IsPathRooted($Root)){throw 'Backup root must be absolute'}
    $full=[IO.Path]::GetFullPath($Root).TrimEnd('\')
    if($full -eq [IO.Path]::GetPathRoot($full).TrimEnd('\')){throw 'Backup root cannot be a drive root'}
    $ancestor=$full
    while($ancestor){
        if(Test-Path -LiteralPath $ancestor){
            if((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Reparse parent: $ancestor"}
        }
        $ancestor=Split-Path -Parent $ancestor
    }
    $child=[IO.Path]::GetFullPath((Join-Path $full $Name))
    if((Split-Path -Parent $child) -ne $full){throw 'Backup path escaped root'}
    Assert-PlainTree $child
    return $child
}

function Remove-BackupChild([string]$Root,[string]$Name) {
    $p=Get-BackupChild $Root $Name
    if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop}
}

function Recover-WorldBackup([string]$Root) {
    $world=Get-BackupChild $Root 'world'
    $previous=Get-BackupChild $Root 'world.previous'
    if(Test-Path -LiteralPath $previous){
        if(-not(Test-Path -LiteralPath $world)){
            Move-Item -LiteralPath $previous -Destination $world -ErrorAction Stop
        }else{
            if(-not(Test-Path -LiteralPath (Join-Path $world 'level.dat') -PathType Leaf)){throw 'Latest world invalid; preserving previous backup'}
            Remove-BackupChild $Root 'world.previous'
        }
    }
}

function Publish-WorldBackup([string]$Root) {
    $incoming=Get-BackupChild $Root 'world.incoming'
    $level=Join-Path $incoming 'level.dat'
    if(-not(Test-Path -LiteralPath $level -PathType Leaf) -or (Get-Item -LiteralPath $level).Length -le 0){throw 'Incoming world is incomplete'}
    Recover-WorldBackup $Root
    $world=Get-BackupChild $Root 'world';$previous=Get-BackupChild $Root 'world.previous'
    if(Test-Path -LiteralPath $world){Move-Item -LiteralPath $world -Destination $previous -ErrorAction Stop}
    try {Move-Item -LiteralPath $incoming -Destination $world -ErrorAction Stop}
    catch {
        if(-not(Test-Path -LiteralPath $world) -and (Test-Path -LiteralPath $previous)){
            Move-Item -LiteralPath $previous -Destination $world -ErrorAction Stop
        }
        throw
    }
    Remove-BackupChild $Root 'world.previous'
}

function Get-WorldManifest([string]$Root,[datetime]$Deadline=[datetime]::MaxValue) {
    Assert-PlainTree $Root
    $prefix=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    $map=@{}
    foreach($f in (Get-ChildItem -LiteralPath $Root -File -Recurse -Force -ErrorAction Stop)) {
        if([DateTime]::UtcNow -ge $Deadline){throw 'Backup verification time budget exceeded'}
        if($f.Name -ieq 'session.lock'){continue}
        $key=$f.FullName.Substring($prefix.Length)
        $stream=[IO.File]::Open($f.FullName,'Open','Read','ReadWrite')
        $sha=[Security.Cryptography.SHA256]::Create()
        try{$hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()}
        $map[$key]=@{bytes=$f.Length;sha256=$hash}
    }
    if(-not $map.ContainsKey('level.dat') -or $map['level.dat'].bytes -le 0){throw 'World level.dat missing or empty'}
    return $map
}

function Assert-MatchingWorlds($Expected,$Actual) {
    if($Expected.Count -ne $Actual.Count){throw 'Backup file count mismatch'}
    foreach($key in $Expected.Keys){
        if(-not $Actual.ContainsKey($key) -or $Expected[$key].bytes -ne $Actual[$key].bytes -or $Expected[$key].sha256 -ne $Actual[$key].sha256){throw "Backup hash mismatch: $key"}
    }
}
