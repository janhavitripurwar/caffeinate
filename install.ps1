# Installs caffeinate for the current user so it runs from any terminal.
#
#   irm https://raw.githubusercontent.com/janhavitripurwar/caffeinate/main/install.ps1 | iex
#
# Downloads the latest caffeinate.exe into %LOCALAPPDATA%\Programs\caffeinate
# and adds that folder to your user PATH. No admin rights needed.
# To uninstall: delete that folder and remove it from your user PATH.

& {
    $ErrorActionPreference = 'Stop'

    $url = 'https://github.com/janhavitripurwar/caffeinate/releases/latest/download/caffeinate.exe'
    $dir = Join-Path $env:LOCALAPPDATA 'Programs\caffeinate'
    $exe = Join-Path $dir 'caffeinate.exe'

    # Windows PowerShell 5.1 may default to TLS 1.0, which GitHub rejects.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Write-Host "Downloading caffeinate..."
    New-Item -ItemType Directory -Force $dir | Out-Null
    $tmp = "$exe.download"
    Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing
    try {
        Move-Item $tmp $exe -Force
    } catch {
        Remove-Item $tmp -ErrorAction SilentlyContinue
        throw "Could not replace $exe. If caffeinate is running, stop it (Ctrl+C) and try again."
    }

    # Read and write the raw registry value so entries like %USERPROFILE%\bin
    # in your PATH are kept as they are.
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    $raw = [string] $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $entries = $raw -split ';' | Where-Object { $_ }
    $present = $entries | Where-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -ieq $dir }

    if ($present) {
        Write-Host "$dir is already on your PATH."
    } else {
        $key.SetValue('Path', (($entries + $dir) -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)

        # Tell Windows the environment changed so new terminals pick it up.
        if (-not ('Caffeinate.Env' -as [type])) {
            Add-Type -Namespace Caffeinate -Name Env -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
'@
        }
        $result = [UIntPtr]::Zero
        [Caffeinate.Env]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref] $result) | Out-Null

        Write-Host "Added $dir to your PATH."
    }
    $key.Close()

    # Make it usable in this window too, without reopening it.
    if (($env:Path -split ';') -notcontains $dir) { $env:Path += ";$dir" }

    $version = & $exe --version
    Write-Host ""
    Write-Host "Installed $version. Run 'caffeinate -d' from any terminal (open a new window first)."
}
