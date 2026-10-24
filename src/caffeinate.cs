// caffeinate for Windows - a port of macOS caffeinate(8).
//
// Holds a Windows power request (the equivalent of a macOS IOPM power
// assertion) for as long as this process runs. Releasing is automatic: the
// request is cleared on Ctrl+C, and the kernel also drops it if the process
// dies for any other reason, so nothing is changed permanently.
//
// Supported flags:
//   -d   prevent the display from sleeping (PowerRequestDisplayRequired)

using System;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;

[assembly: AssemblyTitle("caffeinate")]
[assembly: AssemblyProduct("caffeinate")]
[assembly: AssemblyDescription("Keep Windows awake from the terminal, like macOS caffeinate")]
[assembly: AssemblyVersion(Caffeinate.Version + ".0")]
[assembly: AssemblyFileVersion(Caffeinate.Version + ".0")]
[assembly: AssemblyInformationalVersion(Caffeinate.Version)]

static class Caffeinate
{
    // Bump this for each release; tools/winget-manifest.ps1 checks the released .exe reports it.
    public const string Version = "0.1.0";

    const string Reason = "caffeinate: preventing sleep";

    static int Main(string[] args)
    {
        bool display = false;

        foreach (string arg in args)
        {
            if (arg == "-h" || arg == "--help" || arg == "/?")
            {
                PrintUsage();
                return 0;
            }
            if (arg == "-v" || arg == "--version")
            {
                Console.WriteLine("caffeinate " + Version);
                return 0;
            }
            if (!arg.StartsWith("-") || arg.Length < 2)
                return Fail("unexpected argument '" + arg + "'");

            // Allow combined flags like macOS does (e.g. -di later on).
            foreach (char flag in arg.Substring(1))
            {
                switch (flag)
                {
                    case 'd': display = true; break;
                    default: return Fail("unsupported option -- " + flag);
                }
            }
        }

        if (!display)
            return Fail("no assertion requested (only -d is supported so far)");

        var request = new PowerRequest(Reason);
        if (display)
            request.Set(PowerRequestType.DisplayRequired);

        var stop = new ManualResetEvent(false);
        Console.CancelKeyPress += (sender, e) =>
        {
            e.Cancel = true; // let Main unwind and release cleanly
            stop.Set();
        };

        Console.Error.WriteLine("caffeinate: holding display awake (Ctrl+C to stop)");
        stop.WaitOne();

        request.Dispose();
        return 0;
    }

    static int Fail(string message)
    {
        Console.Error.WriteLine("caffeinate: " + message);
        PrintUsage();
        return 1;
    }

    static void PrintUsage()
    {
        Console.Error.WriteLine("usage: caffeinate -d");
        Console.Error.WriteLine("  -d   prevent the display from sleeping");
        Console.Error.WriteLine("  -h   show this help");
        Console.Error.WriteLine("  -v   show the version");
    }
}

enum PowerRequestType
{
    DisplayRequired = 0,
    SystemRequired = 1,
    AwayModeRequired = 2,
    ExecutionRequired = 3,
}

sealed class PowerRequest : IDisposable
{
    const uint POWER_REQUEST_CONTEXT_VERSION = 0;
    const uint POWER_REQUEST_CONTEXT_SIMPLE_STRING = 0x1;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct REASON_CONTEXT
    {
        public uint Version;
        public uint Flags;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string SimpleReasonString;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr PowerCreateRequest(ref REASON_CONTEXT context);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool PowerSetRequest(IntPtr handle, PowerRequestType type);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool PowerClearRequest(IntPtr handle, PowerRequestType type);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr handle);

    static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    IntPtr handle;
    uint activeTypes; // bitmask of PowerRequestType values currently set

    public PowerRequest(string reason)
    {
        var context = new REASON_CONTEXT
        {
            Version = POWER_REQUEST_CONTEXT_VERSION,
            Flags = POWER_REQUEST_CONTEXT_SIMPLE_STRING,
            SimpleReasonString = reason,
        };
        handle = PowerCreateRequest(ref context);
        if (handle == INVALID_HANDLE_VALUE || handle == IntPtr.Zero)
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }

    public void Set(PowerRequestType type)
    {
        if (!PowerSetRequest(handle, type))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        activeTypes |= 1u << (int)type;
    }

    public void Dispose()
    {
        if (handle == IntPtr.Zero)
            return;
        for (int t = 0; t < 4; t++)
            if ((activeTypes & (1u << t)) != 0)
                PowerClearRequest(handle, (PowerRequestType)t);
        CloseHandle(handle);
        handle = IntPtr.Zero;
    }
}
