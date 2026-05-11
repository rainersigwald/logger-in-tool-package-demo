# LoggerInToolPackageDemo

A self-contained demonstration of how to ship an MSBuild logger inside a
.NET tool package and have callers attach it with a single CLI gesture
using [`dotnet dnx`][dnx].

## The problem

MSBuild loggers are loaded by the build engine via `-logger:<assembly path>`
on the `dotnet build` / `msbuild` command line. That means the logger DLL
has to be **on disk** at the moment the build is invoked. A regular NuGet
package doesn't help: it lives in `~/.nuget/packages` (or wherever) but
isn't automatically present in any well-known place at build time, and you
can't really expect users to extract a `.nupkg` by hand.

## The trick

`dotnet dnx` (introduced in the .NET 10 SDK) downloads + invokes a tool in
a single CLI gesture, extracting the package to a cache on disk. So we
ship the logger DLL **alongside** a trivial .NET tool. The tool's only job
is to print the `-logger:<absolute path>` argument pointing at its sibling
DLL on disk:

```csharp
string toolDir = AppContext.BaseDirectory;
string loggerPath = Path.Combine(toolDir, "DemoLogger.dll");
Console.Out.Write($"-logger:{loggerPath}");
```

Callers then use shell command substitution to splice that argument into
their build invocation:

```bash
# bash / zsh
dotnet build $(dotnet dnx --yes logger-in-tool-package-demo --prerelease) my.csproj
```

```powershell
# PowerShell
dotnet build (dotnet dnx --yes logger-in-tool-package-demo --prerelease) my.csproj
```

The `dotnet dnx` invocation produces exactly one line on stdout —
`-logger:<absolute path to extracted DemoLogger.dll>` — which becomes a
single command-line argument to `dotnet build`. MSBuild then loads the
DLL from that path and the logger is attached.

## How the package is built

The repo has two projects in one solution:

| Project          | TFM            | Role                                         |
| ---------------- | -------------- | -------------------------------------------- |
| `DemoLogger`     | netstandard2.0 | Class library implementing `ILogger`. `IsPackable=false` — ships *inside* the tool package, not as its own NuGet package. |
| `DemoLoggerTool` | net8.0         | `PackAsTool=true` console app. Prints `-logger:<path>` to stdout. |

The interesting bit is in `src/DemoLoggerTool/DemoLoggerTool.csproj`:

```xml
<ProjectReference Include="..\DemoLogger\DemoLogger.csproj"
                  ReferenceOutputAssembly="false"
                  OutputItemType="None"
                  CopyToOutputDirectory="PreserveNewest"
                  Private="false"
                  SkipGetTargetFrameworkProperties="true"
                  UndefineProperties="TargetFramework" />
```

`ReferenceOutputAssembly="false"` means the tool does *not* take a managed
reference on the logger — it never calls into it. `OutputItemType="None"` +
`CopyToOutputDirectory="PreserveNewest"` causes the logger's build output
(`DemoLogger.dll`) to be copied next to the tool exe in the build output
directory as a `None` item.

`OutputItemType="None"` is deliberate: if you use `OutputItemType="Content"`
(the more commonly cited recipe), NuGet will *also* auto-pack the DLL into
`content/` and `contentFiles/`, producing duplicates and `NU5100` warnings.
`None` items respect `CopyToOutputDirectory` but aren't auto-packaged.

Because `PackAsTool` packs everything in the publish output, the logger DLL
ends up in `tools/<tfm>/any/` in the .nupkg — right next to the tool exe,
exactly where `AppContext.BaseDirectory` will point at runtime.

> ⚠️ **Logger must be dependency-free at runtime.** This pattern only drags
> a single DLL (`DemoLogger.dll`) into the publish output. It works because
> our logger has no runtime dependencies beyond the MSBuild assemblies
> supplied by the host process. If you grow your logger to depend on a
> third-party package, you'll need a more involved target that copies the
> full publish closure of the logger project into the tool's publish
> output, or your tool will appear to work but the logger will fail to
> load at build time with a `FileNotFoundException`.

## Trying it locally

```powershell
./sample/pack-and-run.ps1
```

This packs the tool to a local `artifacts/` feed, then uses
`dotnet dnx --add-source artifacts` to fetch and invoke it as part of a
`dotnet build` against `sample/HelloWorld/`. Expect to see lines like:

```
===== DemoLogger v0.1.0.0 attached =====
...
===== DemoLogger: build succeeded in 00:00.123, 0 error(s), 0 warning(s) =====
```

in the build output.

## Caveats

- **Paths with spaces in POSIX shells.** The tool prints
  `-logger:<absolute path>` as a single token. In bash / zsh, naive
  `$(...)` substitution does word-splitting on whitespace, so if the
  path contains spaces the build will see `-logger:/Users/Some` followed
  by `User/...` as a separate argument. PowerShell's
  `(dotnet dnx ...)` subexpression invocation preserves it as a single
  argument and is unaffected. In practice `dotnet dnx` extracts the
  package into the NuGet global packages cache (e.g. `~/.nuget/packages/`
  or wherever `NUGET_PACKAGES` points), which on most setups is
  space-free. If yours isn't, on POSIX shells use
  `dotnet build "$(dotnet dnx ...)" my.csproj` to keep the substitution
  as a single quoted argument.
- **One logger per package.** This pattern hardcodes a single sibling
  DLL name (`DemoLogger.dll`). If you need a logger to support
  parameters or to choose between several implementations, pass them
  through after the colon (e.g. `-logger:LoggerType,Path;Param1=Value`)
  — the tool can build that string up however it likes.
- **Logger must be dependency-free at runtime.** See the note in the
  build section above.
- **`dotnet dnx` requires the .NET 10 SDK.** Older SDKs don't have it;
  callers will need to either upgrade or fall back to
  `dotnet tool install --global` and invoke the tool directly.

## Files of interest

- [`src/DemoLogger/DemoLogger.cs`](src/DemoLogger/DemoLogger.cs) —
  the logger implementation (banner on `BuildStarted`, summary on
  `BuildFinished`).
- [`src/DemoLoggerTool/DemoLoggerTool.csproj`](src/DemoLoggerTool/DemoLoggerTool.csproj) —
  the `PackAsTool` project + the `ProjectReference` trick.
- [`src/DemoLoggerTool/Program.cs`](src/DemoLoggerTool/Program.cs) —
  the four-line tool entrypoint.
- [`sample/pack-and-run.ps1`](sample/pack-and-run.ps1) —
  end-to-end local validation.

## License

MIT.

[dnx]: https://learn.microsoft.com/dotnet/core/tools/dotnet-dnx
