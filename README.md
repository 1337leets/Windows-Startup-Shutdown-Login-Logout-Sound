# Windows-Startup-Shutdown-Login-Logout-Sound
Adding the Windows Startup/Shutdown/Login/Logoff Sounds that are removed or disabled.

This project restores the classic Windows startup, shutdown, logon, and logoff sounds that were removed or disabled in newer versions of Windows.

It uses PowerShell and registry modifications to re-enable and bind the corresponding system sound events.

## Features
- Re-enables Startup sound
- Re-enables Shutdown sound
- Re-enables Logon sound
- Re-enables Logoff sound
- Supports custom sound replacement
- Lightweight and reversible

## Requirements
- Windows 10 / Windows 11
- Administrator privileges
- PowerShell enabled

## Installation

1. Download the latest release.
2. Extract the ZIP archive.
3. Move the extracted folder to `C:\`
4. Run the PowerShell script as Administrator.
5. Restart your system.

## Custom Sounds

To use custom sounds:

- Replace the `.wav` files inside the folder.
- Keep the original filenames.
- Make sure the files are in WAV format.

## Notes

- The script modifies registry keys related to system sound events.
- Changes can be reverted by restoring default registry values.
- This project does not modify system binaries.
