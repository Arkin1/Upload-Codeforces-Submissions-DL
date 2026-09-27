param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Handle,

    [Parameter(Mandatory = $true)]
    [string]$ApiKey,

    [Parameter(Mandatory = $true)]
    [string]$ApiSecret,

    [int]$Retries = 3,

    [int]$Count = 100000
)

$SubmissionsPath = "data/submissions"

function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "$timestamp [$Level] $Message"
}

function Get-Sha512Hex {
    param([string]$InputString)
    $sha512 = [System.Security.Cryptography.SHA512]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        $hashBytes = $sha512.ComputeHash($bytes)
        return -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
    }
    finally {
        $sha512.Dispose()
    }
}

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries,
        [string]$ContextName
    )

    $numRetries = 0
    $errorLog = @()

    while ($numRetries -le $MaxRetries) {
        try {
            return & $ScriptBlock
        }
        catch {
            $errMsg = $_ | Out-String
            Write-Log -Level "WARNING" -Message "Retry $numRetries / $MaxRetries with error: $errMsg"
            $errorLog += $errMsg
            $numRetries++
        }
    }

    for ($i = 0; $i -lt $errorLog.Count; $i++) {
        Write-Log -Level "ERROR" -Message "Retry $i / $MaxRetries with error: $($errorLog[$i])"
    }
    Write-Log -Level "ERROR" -Message "Number of retries exceeded for context $ContextName"
    throw "Number of retries exceeded for context $ContextName!"
}

function Get-SubmissionsUser {
    param(
        [string]$UserId,
        [string]$CodeforcesApiKey,
        [string]$CodeforcesApiSecret,
        [int]$NumberRetries = 3,
        [int]$Count = 10000
    )

    $idx = 1
    $submissions = @()

    Write-Log -Level "INFO" -Message "Retrieving submissions for user $UserId with max $Count submissions per view"

    while ($true) {
        $getSubmissionView = {
            Start-Sleep -Seconds 2
            $myTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

            $rand = "x1y1x2"
            $hashInput = "$rand/user.status?apiKey=$CodeforcesApiKey&count=$Count&from=$idx&handle=$UserId&includeSources=true&time=$myTime#$CodeforcesApiSecret"
            $hsh = Get-Sha512Hex -InputString $hashInput

            $url = "https://codeforces.com/api/user.status?apiKey=$CodeforcesApiKey&count=$Count&from=$idx&handle=$UserId&includeSources=true&time=$myTime&apiSig=$rand$hsh"

            $response = Invoke-RestMethod -Uri $url -Method Get
            return $response.result
        }

        $submissionsView = Invoke-WithRetry -ScriptBlock $getSubmissionView -MaxRetries $NumberRetries -ContextName "GetSubmissionsUser"

        if ($null -eq $submissionsView -or $submissionsView.Count -eq 0) {
            break
        }

        Write-Log -Level "INFO" -Message "Retrieved submissions from $idx to $($idx + $submissionsView.Count - 1)"
        $submissions += $submissionsView

        $idx += $submissionsView.Count
    }

    Write-Log -Level "INFO" -Message "Retrieved all submissions!"
    return $submissions
}

if (-not (Test-Path -Path $SubmissionsPath)) {
    New-Item -ItemType Directory -Path $SubmissionsPath -Force | Out-Null
}

$submissions = Get-SubmissionsUser -UserId $Handle -CodeforcesApiKey $ApiKey -CodeforcesApiSecret $ApiSecret -NumberRetries $Retries -Count $Count

$outputFile = Join-Path -Path $SubmissionsPath -ChildPath "$($Handle)_submissions.json"
$submissions | ConvertTo-Json -Depth 20 | Out-File -FilePath $outputFile -Encoding utf8

Write-Log -Level "INFO" -Message "Saved submissions to $outputFile"
