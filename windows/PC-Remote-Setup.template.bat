@echo off
rem ======================================================================================================
rem  PC Remote - lets the server's administrator work on THIS computer like on a server (files, commands).
rem  Run it once (double-click; Windows asks "Yes" for Administrator rights). Valid until @@EXPIRES@@.
rem  Nothing is opened to the internet or to the local network: this computer keeps an encrypted tunnel
rem  to the server (@@HOST@@), and its SSH server listens only on 127.0.0.1 of this computer, keys only.
rem  Undo everything:  PC-Remote-Setup.bat remove
rem  Independent of NMarketing / InstAI - it is for the whole computer.
rem ======================================================================================================
setlocal
set "PCR_SELF=%~f0"
set "PCR_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:PCR_SELF); $i=$s.IndexOf('#<PS1'+'>'); Invoke-Expression $s.Substring($i)"
if "%ERRORLEVEL%"=="3" exit /b 0
echo.
pause
exit /b 0
#<PS1>
$HostName = '@@HOST@@'
$KnownHosts = '@@KNOWN_HOSTS@@'
$EnrollKeyB64 = '@@ENROLL_KEY_B64@@'
$ZipSha = '@@ZIP_SHA256@@'
$Root = Join-Path $env:ProgramData 'PCRemote'
$TaskPath = '\PCRemote\'
$TaskName = 'PC Remote tunnel'
$SshData = Join-Path $env:ProgramData 'ssh'
$SshdConfig = Join-Path $SshData 'sshd_config'
$AdminKeys = Join-Path $SshData 'administrators_authorized_keys'
$BlockBegin = '# >>> PC Remote: only through the tunnel to the server'
$BlockEnd = '# <<< PC Remote'
$KeyMark = 'pc-remote-admin'
$Utf8 = New-Object Text.UTF8Encoding $false

function Say($m) { Write-Host $m }

function Is-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-Tool($name) {
    foreach ($d in @((Join-Path $env:SystemRoot 'System32\OpenSSH'), (Join-Path $env:ProgramFiles 'OpenSSH'))) {
        $p = Join-Path $d $name
        if (Test-Path -LiteralPath $p) { return $p }
    }
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

function Lock-Down($path) {
    # only Administrators + SYSTEM (ssh refuses keys that others can read)
    if (Test-Path -LiteralPath $path -PathType Container) {
        $null = & icacls.exe $path /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F'
    } else {
        $null = & icacls.exe $path /inheritance:r /grant:r '*S-1-5-32-544:F' '*S-1-5-18:F'
    }
}

function Run-Native($exe, $argLine, $stdinFile) {
    # Start-Process + files: binary-safe and no PowerShell 5.1 stderr surprises
    $out = Join-Path $Root ('run-' + [guid]::NewGuid().ToString('N') + '.out')
    $err = $out + '.err'
    $p = @{ FilePath = $exe; ArgumentList = $argLine; NoNewWindow = $true; Wait = $true; PassThru = $true;
            RedirectStandardOutput = $out; RedirectStandardError = $err }
    if ($stdinFile) { $p.RedirectStandardInput = $stdinFile }
    $proc = Start-Process @p
    $o = ''; $e = ''
    if (Test-Path -LiteralPath $out) { $o = [IO.File]::ReadAllText($out) }
    if (Test-Path -LiteralPath $err) { $e = [IO.File]::ReadAllText($err) }
    Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
    return @{ Code = $proc.ExitCode; Out = $o; Err = $e }
}

function Ssh-Args($request) {
    return ('-i "{0}" -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=yes -o "UserKnownHostsFile={1}" pcenroll@{2} {3}' -f `
            (Join-Path $Root 'enroll_key'), (Join-Path $Root 'known_hosts'), $HostName, $request)
}

function Ask-Server($request, $body) {
    $ssh = Find-Tool 'ssh.exe'
    if (-not $ssh) { throw 'this Windows has no ssh.exe (OpenSSH client): Settings > Apps > Optional features > add "OpenSSH Client"' }
    $in = Join-Path $Root 'request.json'
    [IO.File]::WriteAllText($in, ($body | ConvertTo-Json -Compress), $Utf8)
    $r = Run-Native $ssh (Ssh-Args $request) $in
    Remove-Item -LiteralPath $in -Force -ErrorAction SilentlyContinue
    $line = $r.Out -split "`n" | Where-Object { $_.Trim().StartsWith('{') } | Select-Object -Last 1
    if (-not $line) { throw ('the server did not answer: ' + ($r.Err + ' ' + $r.Out).Trim()) }
    return ($line | ConvertFrom-Json)
}

function Ensure-Sshd {
    if (Get-Service sshd -ErrorAction SilentlyContinue) {
        Say '[1/6] OpenSSH server: already installed'
    } else {
        Say '[1/6] OpenSSH server: adding the Windows feature (may take a few minutes) ...'
        try { $null = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop }
        catch { Say ('    Windows could not add it: ' + $_.Exception.Message) }
        if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
            Say '    taking the copy from the server instead ...'
            $ssh = Find-Tool 'ssh.exe'
            if (-not $ssh) { throw 'this Windows has no ssh.exe (OpenSSH client): Settings > Apps > Optional features > add "OpenSSH Client"' }
            $zip = Join-Path $Root 'OpenSSH-Win64.zip'
            $null = Start-Process -FilePath $ssh -ArgumentList (Ssh-Args 'openssh-zip') -NoNewWindow -Wait `
                    -RedirectStandardOutput $zip -RedirectStandardError ($zip + '.err')
            if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $ZipSha.ToUpper()) { throw 'the OpenSSH package from the server is damaged' }
            $tmp = Join-Path $Root 'openssh-unzip'
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
            Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
            $dest = Join-Path $env:ProgramFiles 'OpenSSH'
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item -Path (Join-Path $tmp 'OpenSSH-Win64\*') -Destination $dest -Recurse -Force
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dest 'install-sshd.ps1') | Out-Null
            Remove-Item -LiteralPath $tmp, $zip, ($zip + '.err') -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) { throw 'the OpenSSH server could not be installed' }
    }
    Set-Service sshd -StartupType Automatic
    Start-Service sshd
    for ($i = 0; $i -lt 30 -and -not (Test-Path -LiteralPath $SshdConfig); $i++) { Start-Sleep -Seconds 1 }
    if (-not (Test-Path -LiteralPath $SshdConfig)) { throw "sshd did not write $SshdConfig" }
}

function Configured-Text($lines) {
    $keep = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($ln in $lines) {
        $t = $ln.Trim()
        if ($t -eq $BlockBegin) { $skip = $true; continue }
        if ($skip) { if ($t -eq $BlockEnd) { $skip = $false }; continue }
        if ($t -match '^(?i)listenaddress\s') { $ln = '#PCR# ' + $ln }
        $keep.Add($ln)
    }
    $block = @($BlockBegin, 'ListenAddress 127.0.0.1', 'PasswordAuthentication no', 'PubkeyAuthentication yes',
               'PermitEmptyPasswords no', $BlockEnd)
    return ((@($block) + @($keep)) -join "`n") + "`n"
}

function Configure-Sshd {
    Say '[2/6] OpenSSH server: only on 127.0.0.1 of this computer, keys only'
    if (-not (Test-Path -LiteralPath ($SshdConfig + '.before-pc-remote'))) {
        Copy-Item -LiteralPath $SshdConfig -Destination ($SshdConfig + '.before-pc-remote')
    }
    [IO.File]::WriteAllText($SshdConfig, (Configured-Text ([IO.File]::ReadAllLines($SshdConfig))), $Utf8)
    $sshd = Find-Tool 'sshd.exe'
    if ($sshd) {
        $r = Run-Native $sshd ('-t -f "{0}"' -f $SshdConfig) $null
        if ($r.Code -ne 0) { throw ('sshd_config check failed: ' + $r.Err + $r.Out) }
    }
    New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -PropertyType String -Force `
        -Value (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') | Out-Null
    # nothing listens outside this computer, so Windows' inbound rule for port 22 is not needed
    Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue | Disable-NetFirewallRule -ErrorAction SilentlyContinue
    Restart-Service sshd -Force
}

function Tunnel-Cmd($ssh, $info) {
    # `ping` instead of `timeout`: timeout.exe needs a console and the SYSTEM task has none
    $lines = @(
        '@echo off',
        'rem PC Remote tunnel - written by PC-Remote-Setup.bat; run by the task \PCRemote\PC Remote tunnel (SYSTEM)',
        'setlocal',
        'set "D=%~dp0"',
        ':loop',
        'if exist "%D%tunnel.log" for %%A in ("%D%tunnel.log") do if %%~zA GTR 1000000 move /y "%D%tunnel.log" "%D%tunnel.prev.log" >nul',
        ('echo [%date% %time%] connecting to {0}>>"%D%tunnel.log"' -f $info.host),
        ('"{0}" -N -T -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ConnectTimeout=20 -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=%D%known_hosts" -i "%D%tunnel_key" -R 127.0.0.1:{1}:127.0.0.1:22 {2}@{3} >>"%D%tunnel.log" 2>&1' -f $ssh, $info.port, $info.tunnel_user, $info.host),
        'ping -n 16 127.0.0.1 >nul',
        'goto loop'
    )
    return ($lines -join "`r`n") + "`r`n"
}

function Setup {
    Say ('This computer: ' + $env:COMPUTERNAME + ' (user ' + $env:USERNAME + ') -> server ' + $HostName)
    New-Item -ItemType Directory -Force -Path $Root | Out-Null
    Lock-Down $Root
    $ek = Join-Path $Root 'enroll_key'
    [IO.File]::WriteAllBytes($ek, [Convert]::FromBase64String($EnrollKeyB64))
    Lock-Down $ek
    [IO.File]::WriteAllText((Join-Path $Root 'known_hosts'), ($KnownHosts + "`n"), $Utf8)
    Lock-Down (Join-Path $Root 'known_hosts')

    Ensure-Sshd
    Configure-Sshd

    Say '[3/6] tunnel key'
    $tk = Join-Path $Root 'tunnel_key'
    if (-not ((Test-Path -LiteralPath $tk) -and (Test-Path -LiteralPath ($tk + '.pub')))) {
        Remove-Item -LiteralPath $tk, ($tk + '.pub') -Force -ErrorAction SilentlyContinue
        $kg = Find-Tool 'ssh-keygen.exe'
        if (-not $kg) { throw 'ssh-keygen.exe not found' }
        $r = Run-Native $kg ('-q -t ed25519 -N "" -C pc-remote@{0} -f "{1}"' -f $env:COMPUTERNAME, $tk) $null
        if ($r.Code -ne 0) { throw ('ssh-keygen failed: ' + $r.Err) }
    }
    Lock-Down $tk
    $hostKey = (Get-Content -LiteralPath (Join-Path $SshData 'ssh_host_ed25519_key.pub') -Raw).Trim()

    Say '[4/6] registering with the server'
    $info = Ask-Server 'enroll' @{ computer = $env:COMPUTERNAME; user = $env:USERNAME; windows = [Environment]::OSVersion.VersionString;
                                   tunnel_pubkey = (Get-Content -LiteralPath ($tk + '.pub') -Raw).Trim(); host_key = $hostKey }
    if (-not $info.ok) { throw ('the server refused: ' + $info.message) }

    Say '[5/6] the administrator key'
    $old = @()
    if (Test-Path -LiteralPath $AdminKeys) { $old = [IO.File]::ReadAllLines($AdminKeys) | Where-Object { $_.Trim() -and ($_ -notmatch $KeyMark) } }
    $parts = $info.admin_pubkey.Split(' ')
    [IO.File]::WriteAllText($AdminKeys, ((@($old) + @(('{0} {1} {2}' -f $parts[0], $parts[1], $KeyMark))) -join "`n") + "`n", $Utf8)
    Lock-Down $AdminKeys

    Say '[6/6] the tunnel (a SYSTEM task from Windows start-up, restarted if it stops)'
    $ssh = Find-Tool 'ssh.exe'
    [IO.File]::WriteAllText((Join-Path $Root 'tunnel.cmd'), (Tunnel-Cmd $ssh $info), [Text.Encoding]::ASCII)
    Lock-Down (Join-Path $Root 'tunnel.cmd')
    Stop-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    $action = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\cmd.exe') -Argument ('/d /c "{0}"' -f (Join-Path $Root 'tunnel.cmd'))
    $t1 = New-ScheduledTaskTrigger -AtStartup
    $t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 5)
    $principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
                -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Action $action -Trigger $t1, $t2 -Principal $principal `
        -Settings $settings -Description 'PC Remote: keeps the encrypted tunnel to the server open (PC-Remote-Setup.bat)' -Force | Out-Null
    Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName

    Say ''
    Say 'Checking that the server can log in through the tunnel ...'
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 5
        try { $st = Ask-Server 'check' @{ name = $info.name } } catch { $st = @{ ok = $false; message = $_.Exception.Message } }
        if ($st.ok) {
            Remove-Item -LiteralPath $ek -Force -ErrorAction SilentlyContinue
            Say ''
            Say ('OK - the server reaches this computer as "' + $info.name + '".')
            Say 'Undo at any time:  PC-Remote-Setup.bat remove'
            return 0
        }
        if ($i -eq 3 -or $i -eq 8) { Say ('  still waiting: ' + $st.message) }
    }
    Say ('[!] The tunnel did not come up. Its log: ' + (Join-Path $Root 'tunnel.log'))
    if (Test-Path -LiteralPath (Join-Path $Root 'tunnel.log')) { Get-Content -LiteralPath (Join-Path $Root 'tunnel.log') -Tail 8 | ForEach-Object { Say ('    ' + $_) } }
    return 2
}

function Remove-All {
    Say 'Removing PC Remote ...'
    Stop-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'PCRemote' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $AdminKeys) {
        $rest = [IO.File]::ReadAllLines($AdminKeys) | Where-Object { $_.Trim() -and ($_ -notmatch $KeyMark) }
        [IO.File]::WriteAllText($AdminKeys, ((@($rest) -join "`n") + "`n"), $Utf8)
    }
    Stop-Service sshd -Force -ErrorAction SilentlyContinue
    Set-Service sshd -StartupType Manual -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
    Say 'Done: the tunnel, the task and the administrator key are gone; the OpenSSH server is stopped (start-up: manual).'
    return 0
}

if (-not (Is-Admin)) {
    Say 'Asking Windows for Administrator rights ...'
    $a = "$env:PCR_ARGS".Trim()
    if ($a) { Start-Process -FilePath $env:PCR_SELF -ArgumentList $a -Verb RunAs } else { Start-Process -FilePath $env:PCR_SELF -Verb RunAs }
    exit 3
}
$ErrorActionPreference = 'Stop'
try {
    # only the last value: anything a cmdlet wrote to the pipeline inside the function must not become the exit code
    if ("$env:PCR_ARGS".Trim() -eq 'remove') { $code = Remove-All | Select-Object -Last 1 } else { $code = Setup | Select-Object -Last 1 }
} catch {
    Say ''
    Say ('[!] ' + $_.Exception.Message)
    $code = 1
}
exit $code
