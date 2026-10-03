[CmdletBinding()]
param(
    [string]$CompilerPath,
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$releaseDir = Join-Path $repoRoot 'desktop\out\Focusly-win32-x64'
$dependencyDir = Join-Path $repoRoot '.dart_tool\installer-deps'
$runtimePath = Join-Path $dependencyDir 'vc_redist.x64.exe'
$runtimeUrl = 'https://aka.ms/vc14/vc_redist.x64.exe'

if (-not $CompilerPath) {
    $compilerCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($compilerCommand) { $CompilerPath = $compilerCommand.Source }
    else {
        $candidates = @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
            (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
        )
        $CompilerPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
}
if (-not $CompilerPath -or -not (Test-Path -LiteralPath $CompilerPath)) {
    throw 'Inno Setup 6 is required. Install it or supply -CompilerPath pointing to ISCC.exe.'
}

Push-Location $repoRoot
try {
    if (-not $SkipFlutterBuild) {
        & (Join-Path $repoRoot 'desktop\build-desktop.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'Windows desktop release build failed.' }
    }
    foreach ($requiredFile in @('focusly.exe','resources\app\main.cjs','resources\app\web\main.dart.js','resources\app\web\sdk\firebase.js','resources\app\web\assets\assets\scripts\windows_notifications.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $releaseDir $requiredFile))) {
            throw "Release payload is incomplete: $requiredFile is missing."
        }
    }

    New-Item -ItemType Directory -Path $dependencyDir -Force | Out-Null
    if (-not (Test-Path -LiteralPath $runtimePath)) {
        Invoke-WebRequest -Uri $runtimeUrl -OutFile $runtimePath
    }
    $runtimeSignature = Get-AuthenticodeSignature -LiteralPath $runtimePath
    if ($runtimeSignature.Status -ne 'Valid' -or
        $runtimeSignature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        throw 'The Microsoft Visual C++ redistributable signature is invalid. Download a valid copy before building.'
    }
    $runtimeVersion = (Get-Item -LiteralPath $runtimePath).VersionInfo
    $versionLine = Get-Content -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') |
        Where-Object { $_ -match '^version:\s*(\d+\.\d+\.\d+)' } | Select-Object -First 1
    if ($versionLine -notmatch '^version:\s*(\d+\.\d+\.\d+)') { throw 'No app version found in pubspec.yaml.' }
    $appVersion = $Matches[1]
    $arguments = @(
        "/DRepoRoot=$repoRoot",
        "/DAppVersion=$appVersion",
        "/DMinRuntimeMajor=$($runtimeVersion.FileMajorPart)",
        "/DMinRuntimeMinor=$($runtimeVersion.FileMinorPart)",
        "/DMinRuntimeBuild=$($runtimeVersion.FileBuildPart)",
        "/DMinRuntimePatch=$($runtimeVersion.FilePrivatePart)",
        (Join-Path $PSScriptRoot 'focusly.iss')
    )
    & $CompilerPath @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup installer compilation failed.' }

    $installerPath = Join-Path $repoRoot "dist\Focusly-Setup-$appVersion-x64.exe"
    $manifestPath = Join-Path $repoRoot "dist\Focusly-Setup-$appVersion-x64.manifest.json"
    $manifest = [ordered]@{
        application = 'Focusly'
        version = $appVersion
        architecture = 'x64'
        firebaseProject = 'focusly-87187'
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        installer = [System.IO.Path]::GetFileName($installerPath)
        sha256 = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
        bytes = (Get-Item -LiteralPath $installerPath).Length
        vcRuntimeVersion = $runtimeVersion.FileVersion
        vcRuntimeSource = $runtimeUrl
        vcRuntimeSha256 = (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash
    }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Output "Installer created: $installerPath"
}
finally { Pop-Location }
