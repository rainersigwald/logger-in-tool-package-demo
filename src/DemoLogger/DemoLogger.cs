using System;
using System.Diagnostics;
using System.Threading;
using Microsoft.Build.Framework;

namespace LoggerInToolPackageDemo;

/// <summary>
/// A deliberately minimal MSBuild logger used to demonstrate that a logger
/// shipped inside a .NET tool package can be loaded by MSBuild via
/// <c>-logger:&lt;path&gt;</c>.
///
/// On build start it prints a clearly-marked banner so it's obvious the demo
/// logger is attached. On build finish it prints a summary line with the
/// elapsed time, error count, and warning count. Nothing else.
/// </summary>
public sealed class DemoLogger : ILogger
{
    private static readonly string s_version =
        typeof(DemoLogger).Assembly.GetName().Version?.ToString() ?? "?";

    // Multi-node / parallel builds can fire ErrorRaised / WarningRaised
    // concurrently on different threads, so use Interlocked rather than ++.
    private int _errorCount;
    private int _warningCount;
    private Stopwatch? _stopwatch;
    private IEventSource? _eventSource;

    public LoggerVerbosity Verbosity { get; set; } = LoggerVerbosity.Normal;

    public string? Parameters { get; set; }

    public void Initialize(IEventSource eventSource)
    {
        _eventSource = eventSource ?? throw new ArgumentNullException(nameof(eventSource));
        _eventSource.BuildStarted += OnBuildStarted;
        _eventSource.BuildFinished += OnBuildFinished;
        _eventSource.ErrorRaised += OnErrorRaised;
        _eventSource.WarningRaised += OnWarningRaised;
    }

    public void Shutdown()
    {
        if (_eventSource is null)
        {
            return;
        }

        _eventSource.BuildStarted -= OnBuildStarted;
        _eventSource.BuildFinished -= OnBuildFinished;
        _eventSource.ErrorRaised -= OnErrorRaised;
        _eventSource.WarningRaised -= OnWarningRaised;
        _eventSource = null;
    }

    private void OnBuildStarted(object sender, BuildStartedEventArgs e)
    {
        _stopwatch = Stopwatch.StartNew();
        Interlocked.Exchange(ref _errorCount, 0);
        Interlocked.Exchange(ref _warningCount, 0);

        if (Verbosity == LoggerVerbosity.Quiet)
        {
            return;
        }

        Console.Out.WriteLine($"===== DemoLogger v{s_version} attached =====");
    }

    private void OnBuildFinished(object sender, BuildFinishedEventArgs e)
    {
        _stopwatch?.Stop();

        if (Verbosity == LoggerVerbosity.Quiet)
        {
            return;
        }

        string outcome = e.Succeeded ? "succeeded" : "failed";
        string elapsed = _stopwatch is null ? "?" : _stopwatch.Elapsed.ToString(@"mm\:ss\.fff");
        int errors = Volatile.Read(ref _errorCount);
        int warnings = Volatile.Read(ref _warningCount);
        Console.Out.WriteLine(
            $"===== DemoLogger: build {outcome} in {elapsed}, {errors} error(s), {warnings} warning(s) =====");
    }

    private void OnErrorRaised(object sender, BuildErrorEventArgs e) => Interlocked.Increment(ref _errorCount);

    private void OnWarningRaised(object sender, BuildWarningEventArgs e) => Interlocked.Increment(ref _warningCount);
}

