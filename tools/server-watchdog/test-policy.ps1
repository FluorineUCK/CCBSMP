$ErrorActionPreference='Stop'
. "$PSScriptRoot\policy.ps1"
function Assert($condition,$message){if(-not $condition){throw $message}}
$c=@{SuccessSeconds=300;FailureWindowSeconds=900;MaxFailures=3;LaunchGraceSeconds=120}
$s=New-WatchState
$r=Step-WatchState $s @{Kind='Absent';Identity=$null} 1000 $c
Assert ($r.Action -eq 'Start') 'Absent server must request launch'
Assert ($null -ne $s.Attempt) 'Launch must be recorded before executing it'
Write-Output 'PASS: absent -> durable launch intent'
$r=Step-WatchState $s @{Kind='Absent';Identity=$null} 1060 $c
Assert ($r.Action -eq 'Hold') 'Do not retry while launch grace is active'
foreach($t in @(1120,1240,1360)) {
    $r=Step-WatchState $s @{Kind='Absent';Identity=$null} $t $c
}
Assert ($s.Latched -and $r.Action -eq 'Hold') 'Three failed starts must latch'
$r=Step-WatchState $s @{Kind='Absent';Identity=$null} 10000 $c
Assert ($s.Latched -and $r.Action -eq 'Hold') 'Latch must not expire automatically'
Write-Output 'PASS: grace / three failures / permanent latch'
$s=New-WatchState
$null=Step-WatchState $s @{Kind='Absent';Identity=$null} 1000 $c
$null=Step-WatchState $s @{Kind='Alive';Identity='10:born'} 1060 $c
$r=Step-WatchState $s @{Kind='Absent';Identity=$null} 1120 $c
Assert ($s.Failures.Count -eq 1 -and $r.Action -eq 'Start') 'Exit before five minutes is a failed restart'
$null=Step-WatchState $s @{Kind='Alive';Identity='11:born'} 1180 $c
$r=Step-WatchState $s @{Kind='Alive';Identity='11:born'} 1480 $c
Assert ($null -eq $s.Attempt -and $s.Failures.Count -eq 0) 'Five minutes alive must clear consecutive failures'
$r=Step-WatchState $s @{Kind='Absent';Identity=$null} 1540 $c
Assert ($s.Failures.Count -eq 0) 'A later crash after success is not a failed restart'
Write-Output 'PASS: early exit / success after five minutes / new failure chain'
$s=New-WatchState
$s.Failures=@(10,20)
$r=Step-WatchState $s @{Kind='Absent';Identity=$null} 2000 $c
Assert ($s.Failures.Count -eq 0 -and -not $s.Latched) 'Old failures must expire from rolling window'
$s.Paused=$true
$r=Step-WatchState $s @{Kind='Absent';Identity=$null} 2200 $c
Assert ($r.Reason -eq 'paused' -and $s.Failures.Count -eq 0) 'Paused checks cannot restart or count failures'
$s.Paused=$false
$r=Step-WatchState $s @{Kind='Unknown';Identity=$null} 2300 $c
Assert ($r.Action -eq 'Hold' -and $s.Failures.Count -eq 0) 'Uncertain observations must fail closed'
$s=New-WatchState
$s.Failures=@(900,950)
$s.Attempt=@{Requested=1000;Identity='99:old';SeenSince=1000}
$r=Step-WatchState $s @{Kind='Alive';Identity='99:new'} 1060 $c
Assert ($s.Latched -and $r.Action -eq 'Hold') 'PID reuse/manual replacement cannot hide third failed restart'
$serialized=$s|ConvertTo-Json -Depth 6
$loaded=$serialized|ConvertFrom-Json
$r=Step-WatchState $loaded @{Kind='Absent';Identity=$null} 20000 $c
Assert ($loaded.Latched -and $r.Action -eq 'Hold') 'Serialized latch must survive across checks'
Write-Output 'PASS: rolling window / pause / uncertain identity / PID reuse / persisted latch'
