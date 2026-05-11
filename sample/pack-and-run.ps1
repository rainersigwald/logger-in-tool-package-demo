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

Write-Host "==> Cleaning artifacts/" -ForegroundColor Cyan
if (Test-Path $artifactsDir) { Remove-Item $artifactsDir -Recurse -Force }
New-Item -ItemType Directory -Path $artifactsDir | Out-Null

Write-Host "==> Packing $toolProject -> $artifactsDir" -ForegroundColor Cyan
dotnet pack $toolProject -c Release -o $artifactsDir | Out-Host
if ($LASTEXITCODE -ne 0) { throw "pack failed" }

Write-Host "==> Resolving logger argument via dotnet dnx" -ForegroundColor Cyan
# `dotnet dnx` writes informational lines (restore output etc.) to stderr,
# so the captured stdout is just the tool's own output: `-logger:<absolute path>`.
$loggerArg = & dotnet dnx --add-source $artifactsDir --prerelease --yes logger-in-tool-package-demo
if ($LASTEXITCODE -ne 0) { throw "dnx invocation failed" }
Write-Host "    $loggerArg"

Write-Host "==> Building $sampleProj with the demo logger attached" -ForegroundColor Cyan
dotnet build $sampleProj $loggerArg -v:minimal -nodeReuse:false | Out-Host
if ($LASTEXITCODE -ne 0) { throw "build failed" }

Write-Host ""
Write-Host "Done. Look for the '===== DemoLogger ... =====' lines in the build output above." -ForegroundColor Green

