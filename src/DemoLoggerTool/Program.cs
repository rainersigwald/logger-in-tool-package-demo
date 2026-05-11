// This tool exists for one purpose: print the absolute path to the DemoLogger
// DLL that ships alongside it in this same package, formatted as the MSBuild
// `-logger:<path>` command-line argument so it can be slotted directly into a
// `dotnet build` invocation via shell command substitution.
//
// Use:
//     dotnet build $(dotnet dnx --yes logger-in-tool-package-demo --prerelease)
//
// `Console.Out.Write` (no newline) is used so that the captured output is
// exactly the argument string with no trailing whitespace. The substitution
// will tolerate trailing newlines in most shells, but emitting a clean single
// token keeps invariants tight and makes piping safer.
//
// AppContext.BaseDirectory is preferred over Assembly.Location: it is reliable
// in single-file/published scenarios and points at the directory the tool
// host extracted the package to, where the sibling DLL lives.

string toolDir = AppContext.BaseDirectory;
string loggerPath = Path.Combine(toolDir, "DemoLogger.dll");

if (!File.Exists(loggerPath))
{
    // Fail fast with a clear, user-visible error rather than letting MSBuild
    // try to load a path that doesn't exist and produce a less obvious failure.
    Console.Error.WriteLine(
        $"logger-in-tool-package-demo: expected sibling logger DLL at '{loggerPath}' but it was not found. " +
        "The package is malformed; please report this.");
    return 1;
}

Console.Out.Write($"-logger:{loggerPath}");
return 0;


