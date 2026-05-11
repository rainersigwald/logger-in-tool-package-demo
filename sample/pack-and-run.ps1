#!/usr/bin/env pwsh
#
# Demo: pack the LoggerInToolPackageDemo tool to a local feed, then use
# `dotnet dnx` to fetch + invoke it from inside a `dotnet build` command line.
#
# Run from anywhere; paths are resolved relative to this script.

$ErrorActionPreference = 'Stop'

$repoRoot     = Resolve-Path (Join-Path $PSScriptRoot '..')
$artifactsDir = Join-Path $repoRoot 'artifacts'
$toolProject  = Join-Path $repoRoot 'src/DemoLoggerTool/DemoLoggerTool.csproj'
$sampleProj   = Join-Path $PSScriptRoot 'HelloWorld/HelloWorld.csproj'

$packageId    = 'logger-in-tool-package-demo'

Write-Host "==> Cleaning artifacts/" -ForegroundColor Cyan
if (Test-Path $artifactsDir) { Remove-Item $artifactsDir -Recurse -Force }
New-Item -ItemType Directory -Path $artifactsDir | Out-Null

Write-Host "==> Removing $packageId from the NuGet global packages cache" -ForegroundColor Cyan
# The package version doesn't change between runs, so we must evict any cached
# copy or `dotnet dnx` will silently reuse the previous build's logger DLL.
$globalPackagesLine = (& dotnet nuget locals global-packages --list) | Select-Object -First 1
$globalPackagesDir  = ($globalPackagesLine -split ':\s*', 2)[1].Trim()
$cachedPackageDir   = Join-Path $globalPackagesDir $packageId
if (Test-Path $cachedPackageDir) { Remove-Item $cachedPackageDir -Recurse -Force }

Write-Host "==> Packing $toolProject -> $artifactsDir" -ForegroundColor Cyan
dotnet pack $toolProject -c Release -o $artifactsDir | Out-Host
if ($LASTEXITCODE -ne 0) { throw "pack failed" }

Write-Host "==> Resolving logger argument via dotnet dnx" -ForegroundColor Cyan
# `dotnet dnx` writes informational lines (restore output etc.) to stderr,
# so the captured stdout is just the tool's own output: `-logger:<absolute path>`.
$loggerArg = & dotnet dnx --add-source $artifactsDir --prerelease --yes $packageId
if ($LASTEXITCODE -ne 0) { throw "dnx invocation failed" }
Write-Host "    $loggerArg"

Write-Host "==> Building $sampleProj with the demo logger attached" -ForegroundColor Cyan
dotnet build $sampleProj $loggerArg -v:minimal -nodeReuse:false | Out-Host
if ($LASTEXITCODE -ne 0) { throw "build failed" }

Write-Host ""
Write-Host "Done. Look for the '===== DemoLogger ... =====' lines in the build output above." -ForegroundColor Green

