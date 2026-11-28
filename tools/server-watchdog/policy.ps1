function New-WatchState {
    return @{ Version=1; Paused=$false; Latched=$false; Failures=@(); Attempt=$null; LastCheck=$null; LastReason='new' }
}

function Step-WatchState($State, $Observation, [double]$Now, $Config) {
    $State.LastCheck=$Now
    if ($State.Paused) { return @{Action='Hold';Reason='paused'} }
    if ($State.Latched) { return @{Action='Hold';Reason='latched'} }
    if ($Observation.Kind -eq 'Alive') {
        if ($null -ne $State.Attempt) {
            if ($null -eq $State.Attempt.Identity) {
                $State.Attempt.Identity=$Observation.Identity
                $State.Attempt.SeenSince=$Now
            } elseif ($State.Attempt.Identity -ne $Observation.Identity) {
                # A manually started replacement is not proof the attempted process survived.
                $State.Failures=@($State.Failures | Where-Object { $Now - [double]$_ -le $Config.FailureWindowSeconds })+@($Now)
                $State.Attempt=@{Requested=$Now;Identity=$Observation.Identity;SeenSince=$Now}
                if ($State.Failures.Count -ge $Config.MaxFailures) {
                    $State.Latched=$true
                    return @{Action='Hold';Reason='three-restarts-failed'}
                }
            }
            if ($Now - $State.Attempt.SeenSince -ge $Config.SuccessSeconds) {
                $State.Failures=@()
                $State.Attempt=$null
                return @{Action='Hold';Reason='restart-successful'}
            }
            return @{Action='Hold';Reason='restart-probation'}
        }
        return @{Action='Hold';Reason='alive'}
    }
    if ($Observation.Kind -ne 'Absent') { return @{Action='Hold';Reason='identity-uncertain'} }
    $State.Failures=@($State.Failures | Where-Object { $Now - [double]$_ -le $Config.FailureWindowSeconds })
    if ($null -ne $State.Attempt) {
        if ($null -eq $State.Attempt.Identity -and $Now - $State.Attempt.Requested -lt $Config.LaunchGraceSeconds) {
            return @{Action='Hold';Reason='launch-grace'}
        }
        $State.Failures=@($State.Failures)+@($Now)
        $State.Attempt=$null
        if ($State.Failures.Count -ge $Config.MaxFailures) {
            $State.Latched=$true
            return @{Action='Hold';Reason='three-restarts-failed'}
        }
    }
    $State.Attempt=@{Requested=$Now;Identity=$null;SeenSince=$null}
    return @{Action='Start';Reason='process-absent'}
}
