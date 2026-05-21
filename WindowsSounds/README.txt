Made by 1337leets

--- Quick Start (GUI) ---

1. Place the WindowsSounds folder in C:\

2. Right-click WindowsSoundManager.ps1 and choose "Run with PowerShell"
   (It will ask for admin permission - this is required to register the sounds.)

3. Use the Browse buttons to pick a WAV file for each event (Startup, Shutdown, Logon, Logoff).

4. Click Apply. The sounds are copied to C:\WindowsSounds\SoundFiles\ and registered
   automatically via Windows Task Scheduler. No manual gpedit.msc steps needed.

5. To remove a sound, click the X button next to it and press Apply.

--- Notes ---

- Only WAV files are supported.
- The GUI saves your selections to C:\WindowsSounds\config.json.
- Task Scheduler tasks are named: WindowsSounds_Startup, WindowsSounds_Shutdown,
  WindowsSounds_Logon, WindowsSounds_Logoff.
- Startup/Shutdown tasks run as SYSTEM. Logon/Logoff tasks run as the current user.
- Shutdown sound fires when Windows begins shutting down (Event ID 1074).
  On very fast shutdowns the sound may be cut short.

