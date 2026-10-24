# caffeinate for Windows

Keep your Windows PC awake from the terminal, the same way `caffeinate -d` works on a Mac.

## The problem

You start something long, like a download, a build, a database load or a big copy, and walk away. When you come back, the screen has gone dark and the machine has gone to sleep, and your work has stalled or broken.

On macOS this is a single command: `caffeinate -d`. Windows has nothing like it built in. You can change your power settings, but then you have to remember to change them back.

## The solution

`caffeinate` is a tiny command-line tool (one 6 KB `.exe`) that keeps your display on for as long as it runs:

```
caffeinate -d
```

Press **Ctrl+C** and your normal sleep settings come back. Nothing is changed permanently. If the window is closed or the process is killed, Windows releases it automatically.

Under the hood it uses the official Windows power API, the same mechanism video players use to stop your screen turning off mid-movie. Nothing fakes mouse movement or key presses.

## Download

1. Download `caffeinate.exe` from the [latest release](https://github.com/<your-github-username>/caffeinate/releases/latest).
2. Open a terminal in the folder where you saved it and run:

   ```powershell
   .\caffeinate.exe -d
   ```

That's it. It works on 64-bit Windows 10 and 11, and there's nothing else to install.

> Windows may show a SmartScreen warning the first time, because the file isn't code-signed yet. Click **More info → Run anyway**.

## Usage

```
caffeinate -d
```

| Option | What it does |
|---|---|
| `-d` | Keep the display from going to sleep |
| `-h` | Show help |
| `-v` | Show the version |

It runs in the foreground until you press **Ctrl+C**:

```
> caffeinate -d
caffeinate: holding display awake (Ctrl+C to stop)
```

To check that it's working, run this in an admin terminal while `caffeinate -d` is running:

```powershell
powercfg /requests
```

`caffeinate.exe` should appear under `DISPLAY`.

**Note:** like the Mac version, it won't stop sleep when you close a laptop lid or choose Sleep from the Start menu yourself.

## Build it yourself

No SDK is needed. The build uses the C# compiler that already ships with Windows.

```powershell
git clone https://github.com/<your-github-username>/caffeinate.git
cd caffeinate
.\build.ps1
```

The program is written to `bin\caffeinate.exe`.

## Coming later

More of the macOS flags: `-i` (keep the system awake), `-t` (stop after a set time), `-w` (stop when another process exits), and `caffeinate <command>` (stay awake until a command finishes).

## License

[MIT](LICENSE)
