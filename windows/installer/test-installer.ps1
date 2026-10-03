[CmdletBinding()]
param([string]$InstallerPath)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$releaseDir = Join-Path $repoRoot 'desktop\out\Focusly-win32-x64'
$testRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '.dart_tool\installer-smoke'))
$installDir = [System.IO.Path]::GetFullPath((Join-Path $testRoot 'app'))
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{CFC97191-614B-4D8A-8266-C9E86F905954}_is1'
$protocolKey = 'HKCU:\Software\Classes\focusly'
$programsDir = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'
$testShortcutDir = Join-Path $programsDir 'Focusly Installer Smoke Test'
$normalShortcut = Join-Path $programsDir 'Focusly\Focusly.lnk'
$normalShortcutHash = if (Test-Path -LiteralPath $normalShortcut) { (Get-FileHash -LiteralPath $normalShortcut).Hash } else { $null }
if (Test-Path -LiteralPath $testShortcutDir) { throw 'The isolated test shortcut group already exists.' }
if (-not $installDir.StartsWith($testRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The test installation path is outside the isolated test directory.'
}
if (Test-Path -LiteralPath $uninstallKey) {
    throw 'Focusly is already installed for this user. The smoke test will not modify that installation.'
}
if (-not $InstallerPath) {
    $InstallerPath = (Get-ChildItem -LiteralPath (Join-Path $repoRoot 'dist') -Filter 'Focusly-Setup-*-x64.exe' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $InstallerPath -or -not (Test-Path -LiteralPath $InstallerPath)) { throw 'No installer was found.' }
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$normalBackup = Join-Path $testRoot 'normal-shortcut-before.lnk'
if (Test-Path -LiteralPath $normalShortcut) {Copy-Item -LiteralPath $normalShortcut -Destination $normalBackup -Force}
$installLog = Join-Path $testRoot 'install.log'
$uninstallLog = Join-Path $testRoot 'uninstall.log'
$verifiedFiles = 0
$installed = $false
$protocolExisted = Test-Path -LiteralPath $protocolKey
$protocolBackup = Join-Path $testRoot 'protocol-before.reg'
if ($protocolExisted) {
    & reg.exe export 'HKCU\Software\Classes\focusly' $protocolBackup /y | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not preserve the existing protocol registration.' }
}
$profileDir = Join-Path $testRoot 'profile'
function Wait-IsolatedAppExit {
    $testExecutable = Join-Path $installDir 'focusly.exe'
    $exitDeadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $remaining = @(Get-CimInstance Win32_Process -Filter "name = 'focusly.exe'" |
            Where-Object { $_.ExecutablePath -eq $testExecutable })
        if ($remaining.Count -eq 0) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $exitDeadline)
    throw 'The isolated app has not exited; refusing to overwrite its open files.'
}
try {
    $installArguments = @(
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/TASKS=', '/LANG=arabic',
        '/GROUP="Focusly Installer Smoke Test"',
        ('/DIR="' + $installDir + '"'),
        ('/LOG="' + $installLog + '"')
    )
    $setup = Start-Process -FilePath $InstallerPath -ArgumentList $installArguments -WindowStyle Hidden -Wait -PassThru
    if ($setup.ExitCode -ne 0) { throw "Installer returned exit code $($setup.ExitCode). See $installLog" }
    $installed = $true
    $registration = Get-ItemProperty -LiteralPath $uninstallKey
    if ($registration.InstallLocation.TrimEnd('\') -ne $installDir.TrimEnd('\')) {
        throw 'Installer registration does not point to the isolated test directory.'
    }
    $payload = Get-ChildItem -LiteralPath $releaseDir -Recurse -File |
        Where-Object { $_.Extension -notin @('.lib', '.exp') }
    foreach ($source in $payload) {
        $relativePath = [System.IO.Path]::GetRelativePath($releaseDir, $source.FullName)
        $destination = Join-Path $installDir $relativePath
        if (-not (Test-Path -LiteralPath $destination)) { throw "Missing installed file: $relativePath" }
        if ((Get-FileHash -LiteralPath $source.FullName).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
            throw "Installed file does not match its release payload: $relativePath"
        }
        $verifiedFiles++
    }
    if (-not (Test-Path -LiteralPath (Join-Path $installDir 'unins000.exe'))) {
        throw 'Uninstaller was not installed.'
    }
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    $marker = Join-Path $profileDir 'upgrade-marker.txt'
    'Keep local preferences across upgrades' | Set-Content -LiteralPath $marker -Encoding utf8
    $markerHash = (Get-FileHash -LiteralPath $marker).Hash
    & node (Join-Path $repoRoot '.dart_tool\implementation\desktop-smoke.cjs') (Join-Path $installDir 'focusly.exe') $profileDir
    if ($LASTEXITCODE -ne 0) { throw 'The installed app failed its startup checks.' }
    Wait-IsolatedAppExit
    $profileFiles = Get-ChildItem -LiteralPath $profileDir -Recurse -File
    if ($profileFiles.Count -lt 5) { throw 'The app did not create its isolated local profile.' }
    $upgrade = Start-Process -FilePath $InstallerPath -ArgumentList $installArguments -WindowStyle Hidden -Wait -PassThru
    if ($upgrade.ExitCode -ne 0) { throw 'The in-place upgrade failed.' }
    if ((Get-FileHash -LiteralPath $marker).Hash -ne $markerHash) { throw 'Upgrade changed the saved local profile.' }
    & node (Join-Path $repoRoot '.dart_tool\implementation\desktop-smoke.cjs') (Join-Path $installDir 'focusly.exe') $profileDir
    if ($LASTEXITCODE -ne 0) { throw 'The upgraded app failed its startup checks.' }
    Wait-IsolatedAppExit
    $env:FOCUSLY_NOTIFICATION_PROOF='1'
    try {
      & node (Join-Path $repoRoot '.dart_tool\implementation\desktop-smoke.cjs') (Join-Path $installDir 'focusly.exe') $profileDir
      if ($LASTEXITCODE -ne 0) { throw 'Native notification scheduling failed.' }
    } finally {Remove-Item Env:FOCUSLY_NOTIFICATION_PROOF -ErrorAction SilentlyContinue}
    Wait-IsolatedAppExit
    $inspectRequest=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"action":"inspect","id":1337707}'))
    $nativeScript=Join-Path $repoRoot 'assets\scripts\windows_notifications.ps1'
    $proof=(& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $nativeScript -RequestBase64 $inspectRequest) | ConvertFrom-Json
    if ($proof.present -ne $true) { throw 'The OS did not retain the reminder after the app closed.' }
    $cancelRequest=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"action":"cancel","id":1337707}'))
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $nativeScript -RequestBase64 $cancelRequest
    if ($LASTEXITCODE -ne 0) { throw 'Could not cancel the isolated test reminder.' }
    $cancelled=(& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $nativeScript -RequestBase64 $inspectRequest) | ConvertFrom-Json
    if ($cancelled.present -ne $false) { throw 'The cancelled reminder remains registered.' }
}
finally {
    if ($installed) {
        $cancelTest=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"action":"cancel","id":1337707}'))
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'assets\scripts\windows_notifications.ps1') -RequestBase64 $cancelTest *> $null
    }
    $uninstaller = Join-Path $installDir 'unins000.exe'
    if (Test-Path -LiteralPath $uninstaller) {
        $registration = Get-ItemProperty -LiteralPath $uninstallKey -ErrorAction Stop
        if ($registration.InstallLocation.TrimEnd('\') -ne $installDir.TrimEnd('\')) {
            throw 'Refusing to uninstall an installation outside the test directory.'
        }
        $uninstallArguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/LOG="' + $uninstallLog + '"'))
        $removal = Start-Process -FilePath $uninstaller -ArgumentList $uninstallArguments -WindowStyle Hidden -Wait -PassThru
        if ($removal.ExitCode -ne 0) { throw "Uninstaller returned exit code $($removal.ExitCode)." }
    }
    if ($protocolExisted) {
        & reg.exe import $protocolBackup | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not restore the existing protocol registration.' }
    }
    if ($normalShortcutHash -ne $null) {
        $shortcutFolder=Split-Path -Parent $normalShortcut
        New-Item -ItemType Directory -Path $shortcutFolder -Force | Out-Null
        Copy-Item -LiteralPath $normalBackup -Destination $normalShortcut -Force
    }
}
if (-not $installed) { throw 'The installation did not complete.' }
if (Test-Path -LiteralPath $uninstallKey) { throw 'The test uninstall registration remains.' }
if (Test-Path -LiteralPath (Join-Path $installDir 'focusly.exe')) { throw 'The installed executable remains after uninstallation.' }
if (Test-Path -LiteralPath $testShortcutDir) { throw 'The isolated test shortcut group remains after uninstallation.' }
$currentShortcutHash = if (Test-Path -LiteralPath $normalShortcut) { (Get-FileHash -LiteralPath $normalShortcut).Hash } else { $null }
if ($currentShortcutHash -ne $normalShortcutHash) { throw 'The normal Focusly shortcut was modified.' }
$receipt = [ordered]@{
    installer = [System.IO.Path]::GetFullPath($InstallerPath)
    verifiedAtUtc = [DateTime]::UtcNow.ToString('o')
    installationLanguage = 'arabic'
    payloadFilesVerified = $verifiedFiles
    payloadHashesMatch = $true
    installPassed = $true
    uninstallPassed = $true
    launchedApplication = $true
    upgradePassed = $true
    scheduledReminderSurvivesExit = $true
    testReminderCancelled = $true
    localProfilePreserved = (Test-Path -LiteralPath $marker)
    originalProtocolRestored = $protocolExisted
    originalInstallationModified = $false
    originalShortcutModified = $false
}
$receipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRoot 'result.json') -Encoding utf8
$receipt | ConvertTo-Json
