$ErrorActionPreference='Stop'
. "$PSScriptRoot\files.ps1"
function Assert($condition,$message){if(-not $condition){throw $message}}
$root=Join-Path $PSScriptRoot ('fixture-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$root\world","$root\world.incoming"|Out-Null
[IO.File]::WriteAllText("$root\world\level.dat",'old')
[IO.File]::WriteAllText("$root\world\stale.txt",'stale')
[IO.File]::WriteAllText("$root\world.incoming\level.dat",'new')
Publish-WorldBackup $root
Assert (([IO.File]::ReadAllText("$root\world\level.dat")) -eq 'new') 'New copy must replace previous'
Assert (-not(Test-Path "$root\world\stale.txt")) 'Stale files must not survive replacement'
Assert (-not(Test-Path "$root\world.previous")) 'Only latest successful backup is retained'
Write-Output 'PASS: overwrite old world and remove stale files'
New-Item -ItemType Directory -Path "$root\world.incoming"|Out-Null
$failed=$false;try{Publish-WorldBackup $root}catch{$failed=$true}
Assert $failed 'Incomplete staging must not be published'
Assert (([IO.File]::ReadAllText("$root\world\level.dat")) -eq 'new') 'Failed copy must preserve old backup'
Move-Item -LiteralPath "$root\world" -Destination "$root\world.previous"
Recover-WorldBackup $root
Assert (Test-Path "$root\world\level.dat") 'Interrupted promotion must restore previous'
$failed=$false;try{Get-BackupChild $root '..\outside'}catch{$failed=$true}
Assert $failed 'Traversal child must be rejected'
$failed=$false;try{Get-BackupChild 'D:\' 'world'}catch{$failed=$true}
Assert $failed 'Drive root must be rejected'
[IO.File]::WriteAllText("$root\world\session.lock",'ignored')
$a=Get-WorldManifest "$root\world"
Assert (-not $a.ContainsKey('session.lock')) 'Session lock must be excluded'
$b=Get-WorldManifest "$root\world"
Assert-MatchingWorlds $a $b
$b['level.dat'].sha256='wrong'
$failed=$false;try{Assert-MatchingWorlds $a $b}catch{$failed=$true}
Assert $failed 'Hash mismatch must be rejected'
Write-Output 'PASS: failed copy preserves old / interrupted promotion / path guards / session lock / hash mismatch'
Write-Output "Evidence: $root"
