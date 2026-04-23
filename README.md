# Run Script As Task

Run `.bat`, `.cmd`, and `.ps1` files in the integrated terminal with one click.

Repository: `https://github.com/Remaderrg/RunScriptAsTask`

## Features

- **Run button** in the editor title bar when a `.bat`, `.cmd`, or `.ps1` file is open
- **Command Palette** — press `Ctrl+Shift+P` and type `Run Script: Run as Task`

## Usage

1. Open a `.bat`, `.cmd`, or `.ps1` file
2. Click the Run button in the editor title bar, or press `Ctrl+Shift+P` → "Run Script: Run as Task"
3. The file runs in the integrated terminal with the correct working directory

## Settings

- **Reuse terminal** (`runbatastask.reuseTerminal`): when enabled (**default**), runs reuse a single terminal tab (the previous one is replaced). When disabled, every run opens a new terminal.

## Requirements

- Windows (for `.bat`/`.cmd` via `cmd.exe`, and `.ps1` via `powershell.exe`). On other platforms, runs via shell (PowerShell uses `pwsh`).
