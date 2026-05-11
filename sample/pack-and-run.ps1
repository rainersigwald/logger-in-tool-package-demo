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

# Use a unique per-run version so each invocation gets a fresh package out of
# the NuGet global packages cache (rather than a stale cached copy from a
# previous run). We can't easily delete the cache between runs because
# MSBuild server may still hold a handle on the previously-loaded logger DLL.
# Milliseconds (fff) prevent collisions on rapid back-to-back invocations.
$version = "0.1.0-dev$((Get-Date).ToString('yyyyMMddHHmmssfff'))"

Write-Host "==> Cleaning artifacts/" -ForegroundColor Cyan
if (Test-Path $artifactsDir) { Remove-Item $artifactsDir -Recurse -Force }
New-Item -ItemType Directory -Path $artifactsDir | Out-Null

Write-Host "==> Packing $toolProject @ $version -> $artifactsDir" -ForegroundColor Cyan
dotnet pack $toolProject -c Release -o $artifactsDir /p:Version=$version | Out-Host
if ($LASTEXITCODE -ne 0) { throw "pack failed" }

Write-Host "==> Resolving logger argument via dotnet dnx" -ForegroundColor Cyan
# `dotnet dnx` writes informational lines (restore output etc.) to stderr,
# so the captured stdout is just the tool's own output: `-logger:<absolute path>`.
$loggerArg = & dotnet dnx --add-source $artifactsDir --version $version --yes logger-in-tool-package-demo
if ($LASTEXITCODE -ne 0) { throw "dnx invocation failed" }
Write-Host "    $loggerArg"

Write-Host "==> Building $sampleProj with the demo logger attached" -ForegroundColor Cyan
dotnet build $sampleProj $loggerArg -v:minimal | Out-Host
if ($LASTEXITCODE -ne 0) { throw "build failed" }

Write-Host ""
Write-Host "Done. Look for the '===== DemoLogger ... =====' lines in the build output above." -ForegroundColor Green

