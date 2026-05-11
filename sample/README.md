# Sample

A trivial console app used as a build target for demonstrating
`LoggerInToolPackageDemo` end-to-end.

## What's here

- `HelloWorld/` — a one-file `net8.0` console app. Nothing about it is
  special; it's just a small project that needs to be *built*.
- `pack-and-run.ps1` — a PowerShell script that:
  1. Packs `src/DemoLoggerTool` into `../artifacts/` (a local NuGet feed).
  2. Invokes `dotnet build` on `HelloWorld/`, expanding
     `dotnet dnx --add-source ../artifacts --yes logger-in-tool-package-demo --prerelease`
     into the build command line so that `-logger:<path>` gets passed through.

## Run it

From the repo root:

```powershell
./sample/pack-and-run.ps1
```

The build output should contain the `===== DemoLogger v… attached =====`
banner near the top and a `===== DemoLogger: build succeeded in … =====`
summary near the bottom.
