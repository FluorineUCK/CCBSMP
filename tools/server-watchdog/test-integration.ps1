param([string]$Java='C:\Program Files\Java\jdk-21.0.11\bin\java.exe')
$ErrorActionPreference='Stop'
$work=Join-Path $PSScriptRoot ('fixture-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work|Out-Null
$cfg=Join-Path $work 'config.json'
$checker=Join-Path $PSScriptRoot 'watchdog.ps1'
$createdPids=[Collections.Generic.List[int]]::new()
function Assert($value,$message){if(-not $value){throw $message}}
function Run($action){
    $out=& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $checker -ConfigPath $cfg -Action $action 2>&1
    if($LASTEXITCODE -ne 0){throw ($out|Out-String)}
}
function State {Get-Content (Join-Path $work 'state.json') -Raw|ConvertFrom-Json}
function Starts {return @((Get-Content (Join-Path $work 'watchdog.jsonl'))|ForEach-Object {$_|ConvertFrom-Json}|Where-Object event -eq 'launched').Count}
function WaitStart([int]$previous){
    $end=[DateTime]::UtcNow.AddSeconds(25)
    do{
        $s=State
        if($null -ne $s.Attempt -and $s.Attempt.Identity -and (Starts) -gt $previous){
            $processId=[int]($s.Attempt.Identity.Split(':')[0]);$createdPids.Add($processId);return $processId
        }
        Start-Sleep -Milliseconds 300
    }while([DateTime]::UtcNow -lt $end)
    throw ('Launch timeout: '+(Get-Content (Join-Path $work 'watchdog.jsonl') -Raw))
}
function StopFixture([int]$processId){
    $p=Get-CimInstance Win32_Process -Filter "ProcessId=$processId"
    if($p -and $p.Name -eq 'java.exe' -and $p.CommandLine.Contains($work)) {Stop-Process -Id $processId -Force -ErrorAction Stop}
}
try{
    [IO.File]::WriteAllText((Join-Path $work 'Harness.java'),'public class Harness { public static void main(String[] a) throws Exception { Thread.sleep(120000); } }')
    & (Join-Path (Split-Path $Java) 'javac.exe') (Join-Path $work 'Harness.java')
    if($LASTEXITCODE -ne 0){throw 'javac failed'}
    [IO.File]::WriteAllText((Join-Path $work 'jvm.args'),"-Xms16m`n-Xmx32m`n")
    [IO.File]::WriteAllText((Join-Path $work 'fixture.args'),('-cp'+"`n"+'"'+$work.Replace('\','/')+'"'+"`nHarness`n"))
    $c=Get-Content "$PSScriptRoot\config.example.json" -Raw|ConvertFrom-Json
    $c.ServerRoot=$work;$c.JavaExe=$Java;$c.JvmArgsFile='jvm.args';$c.ForgeArgsFile='fixture.args';$c.GamePort=54983;$c.SuccessSeconds=4;$c.LaunchGraceSeconds=30
    $c|ConvertTo-Json|Set-Content $cfg -Encoding UTF8
    Run Initialize;Run Check
    Assert ((State).Paused -and (Starts) -eq 0) 'Initial state must be paused'
    Run Resume;Run Check;$processId=WaitStart 0
    Start-Sleep -Seconds 5;Run Check;Run Check
    Assert ($null -eq (State).Attempt -and (Starts) -eq 1) 'Healthy process must survive and not be duplicated'
    Write-Output 'PASS: detached real Java survived checker exit, healthy check, stable success, no duplicate'
    StopFixture $processId;Run Check;$processId=WaitStart 1
    foreach($failures in @(1,2,3)){
        StopFixture $processId;Run Check
        Assert (@((State).Failures).Count -eq $failures) 'Failure counter mismatch'
        if($failures -lt 3){$processId=WaitStart (1+$failures)}
    }
    Assert ((State).Latched -and (Starts) -eq 4) 'Three actual failures must latch'
    Run Check;Run Resume;Run Check
    Assert ((State).Latched -and (Starts) -eq 4) 'Resume must not unlock latch'
    Write-Output 'PASS: three real early exits latch, no fourth restart, Resume cannot clear latch'
    Run Pause;Run Reset;Run Check
    Assert ((State).Paused -and -not (State).Latched -and (Starts) -eq 4) 'Reset must preserve pause'
    Run Resume;Run Check;$processId=WaitStart 4
    Run Pause;StopFixture $processId;Run Check
    Assert ((Starts) -eq 5) 'Paused maintenance must not restart'
    Write-Output 'PASS: pause, reset, resume, manual maintenance'
    [IO.File]::WriteAllText((Join-Path $work 'state.json'),'{corrupted')
    $ErrorActionPreference='Continue'
    $failure=& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $checker -ConfigPath $cfg -Action Check 2>&1
    $code=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    Assert ($code -ne 0 -and (Starts) -eq 5) 'Corrupt state must fail closed'
    Write-Output 'PASS: corrupted state does not restart'
    [IO.File]::WriteAllText((Join-Path $work 'result.txt'),'PASS')
    Write-Output "Evidence: $work"
}finally{foreach($processId in $createdPids){StopFixture $processId}}
