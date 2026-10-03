[CmdletBinding()]
param([switch]$SkipWebBuild)
$ErrorActionPreference='Stop'
$repoRoot=[System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $PSScriptRoot
try {
    & npm ci --no-audit --no-fund
    if($LASTEXITCODE -ne 0){throw 'Desktop dependencies failed.'}
    & npm run bundle-sdk
    if($LASTEXITCODE -ne 0){throw 'Local Firebase SDK bundle failed.'}
    & 'C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' bundle-fallback-fonts.py
    if($LASTEXITCODE -ne 0){throw 'Fallback font bundle failed.'}
    if(-not $SkipWebBuild){
        Push-Location $repoRoot
        try {
            & C:\dev\flutter\bin\flutter.bat build web --release --no-web-resources-cdn --no-wasm-dry-run
            if($LASTEXITCODE -ne 0){throw 'Flutter web release failed.'}
        } finally {Pop-Location}
    }
    $webPayload=Join-Path $PSScriptRoot 'web'
    if(Test-Path -LiteralPath $webPayload){
        $resolved=[System.IO.Path]::GetFullPath($webPayload)
        if($resolved -ne (Join-Path $repoRoot 'desktop\web')){throw 'Unexpected web payload directory.'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    New-Item -ItemType Directory -Path $webPayload -Force | Out-Null
    Copy-Item -Path (Join-Path $repoRoot 'build\web\*') -Destination $webPayload -Recurse -Force
    & node package-desktop.mjs
    if($LASTEXITCODE -ne 0){throw 'Desktop packaging failed.'}
} finally {Pop-Location}
