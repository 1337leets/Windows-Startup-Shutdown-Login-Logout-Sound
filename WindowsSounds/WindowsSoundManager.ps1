#requires -Version 5.1

#region Self-Elevation
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" `
        -Verb RunAs
    exit
}
#endregion

#region Assemblies and Constants
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$SOUNDS_ROOT  = 'C:\WindowsSounds'
$SOUND_FILES  = "$SOUNDS_ROOT\SoundFiles"
$SCRIPT_FILES = "$SOUNDS_ROOT\ScriptFiles"
$CONFIG_PATH  = "$SOUNDS_ROOT\config.json"
$EVENTS       = @('Startup', 'Shutdown', 'Logon', 'Logoff')
$TASK_PREFIX  = 'WindowsSounds_'
$WAV_FILTER   = 'WAV Audio Files (*.wav)|*.wav'
#endregion

#region Config
function Load-Config {
    if (Test-Path $script:CONFIG_PATH) {
        try {
            $raw = Get-Content $script:CONFIG_PATH -Raw | ConvertFrom-Json
            foreach ($e in $script:EVENTS) {
                if ($raw.PSObject.Properties.Name -notcontains $e) {
                    Add-Member -InputObject $raw -NotePropertyName $e `
                        -NotePropertyValue ([PSCustomObject]@{ SourcePath = ''; Enabled = $false })
                }
            }
            return $raw
        } catch { }
    }
    $d = [PSCustomObject]@{}
    foreach ($e in $script:EVENTS) {
        Add-Member -InputObject $d -NotePropertyName $e `
            -NotePropertyValue ([PSCustomObject]@{ SourcePath = ''; Enabled = $false })
    }
    return $d
}

function Save-Config ([PSCustomObject]$cfg) {
    if (-not (Test-Path $script:SOUNDS_ROOT)) {
        New-Item -ItemType Directory -Path $script:SOUNDS_ROOT | Out-Null
    }
    $cfg | ConvertTo-Json -Depth 3 | Set-Content $script:CONFIG_PATH -Encoding UTF8
}
#endregion

#region Play Script Generation
function Write-PlayScript ([string]$EventName) {
    if (-not (Test-Path $script:SCRIPT_FILES)) {
        New-Item -ItemType Directory -Path $script:SCRIPT_FILES | Out-Null
    }
    $destPath = "$script:SOUND_FILES\$EventName.wav"
    $content  = "(New-Object System.Media.SoundPlayer '$destPath').PlaySync()"
    $outPath  = "$script:SCRIPT_FILES\Play$EventName.ps1"
    Set-Content -Path $outPath -Value $content -Encoding UTF8
    return $outPath
}
#endregion

#region Task Scheduler
function Get-ShutdownTaskXml ([string]$ScriptPath) {
    @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Windows shutdown sound</Description></RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='User32'] and EventID=1074]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
    <Priority>4</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$ScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
}

function Get-LogoffTaskXml ([string]$ScriptPath, [string]$UserId, [string]$UserSid) {
    @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Windows logoff sound</Description></RegistrationInfo>
  <Triggers>
    <SessionStateChangeTrigger>
      <Enabled>true</Enabled>
      <StateChange>SessionLogoff</StateChange>
      <UserId>$UserId</UserId>
    </SessionStateChangeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$UserSid</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
    <Priority>4</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$ScriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
}

function Register-SoundTask ([string]$EventName, [string]$ScriptPath) {
    $taskName = "$script:TASK_PREFIX$EventName"
    $argStr   = "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

    switch ($EventName) {
        'Startup' {
            $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argStr
            $trigger   = New-ScheduledTaskTrigger -AtStartup
            $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
            $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
                             -MultipleInstances IgnoreNew
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
                -Principal $principal -Settings $settings -Force | Out-Null
        }
        'Logon' {
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $action      = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argStr
            $trigger     = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
            $principal   = New-ScheduledTaskPrincipal -UserId $currentUser -RunLevel Highest
            $settings    = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
                               -MultipleInstances IgnoreNew
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
                -Principal $principal -Settings $settings -Force | Out-Null
        }
        'Shutdown' {
            $xml = Get-ShutdownTaskXml -ScriptPath $ScriptPath
            Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null
        }
        'Logoff' {
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $sid = ([System.Security.Principal.NTAccount]$currentUser).Translate(
                       [System.Security.Principal.SecurityIdentifier]).Value
            $xml = Get-LogoffTaskXml -ScriptPath $ScriptPath -UserId $currentUser -UserSid $sid
            Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null
        }
    }
}

function Unregister-SoundTask ([string]$EventName) {
    $taskName = "$script:TASK_PREFIX$EventName"
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}
#endregion

#region Apply
function Invoke-Apply ([hashtable]$rows, [PSCustomObject]$cfg,
                       [System.Windows.Forms.Label]$statusLbl,
                       [System.Windows.Forms.Form]$frm) {
    $hasError = $false
    foreach ($eventName in $script:EVENTS) {
        $sourcePath          = $rows[$eventName]
        $statusLbl.Text      = "Processing $eventName..."
        $statusLbl.ForeColor = [System.Drawing.Color]::DimGray
        [System.Windows.Forms.Application]::DoEvents()

        if ([string]::IsNullOrEmpty($sourcePath)) {
            Unregister-SoundTask -EventName $eventName
            $cfg.$eventName.SourcePath = ''
            $cfg.$eventName.Enabled    = $false
        } else {
            try {
                foreach ($dir in @($script:SOUND_FILES, $script:SCRIPT_FILES)) {
                    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
                }
                $dest = "$script:SOUND_FILES\$eventName.wav"
                if ([System.IO.Path]::GetFullPath($sourcePath) -ne [System.IO.Path]::GetFullPath($dest)) {
                    Copy-Item -Path $sourcePath -Destination $dest -Force
                }
                $scriptPath = Write-PlayScript -EventName $eventName
                Register-SoundTask -EventName $eventName -ScriptPath $scriptPath
                $cfg.$eventName.SourcePath = $sourcePath
                $cfg.$eventName.Enabled    = $true
            } catch {
                $hasError = $true
                [System.Windows.Forms.MessageBox]::Show(
                    "Error processing ${eventName}:`n$($_.Exception.Message)",
                    'Windows Sound Manager',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
        }
    }
    Save-Config $cfg
    return (-not $hasError)
}
#endregion

#region GUI
$cfg = Load-Config

# ---- Form ----
$form                 = New-Object System.Windows.Forms.Form
$form.Text            = 'Windows Sound Manager'
$form.Size            = New-Object System.Drawing.Size(660, 310)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false
$form.StartPosition   = 'CenterScreen'
$form.Font            = New-Object System.Drawing.Font('Segoe UI', 9)

# ---- Status label (created before the loop so closures can capture it) ----
$statusLabel           = New-Object System.Windows.Forms.Label
$statusLabel.Text      = 'Ready.'
$statusLabel.ForeColor = [System.Drawing.Color]::DimGray
$statusLabel.AutoSize  = $false
$statusLabel.TextAlign = 'MiddleLeft'
$statusLabel.Dock      = 'Fill'

# ---- TableLayoutPanel ----
$tlp             = New-Object System.Windows.Forms.TableLayoutPanel
$tlp.Dock        = 'Fill'
$tlp.Padding     = New-Object System.Windows.Forms.Padding(10)
$tlp.ColumnCount = 5
$tlp.RowCount    = 6

$tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 110))) | Out-Null
$tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent',  100))) | Out-Null
$tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 80)))  | Out-Null
$tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 80)))  | Out-Null
$tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 36)))  | Out-Null

$tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 28))) | Out-Null
foreach ($_ in 1..4) {
    $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 40))) | Out-Null
}
$tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 50))) | Out-Null

# ---- Header ----
$header           = New-Object System.Windows.Forms.Label
$header.Text      = 'Select a WAV file for each Windows event:'
$header.Dock      = 'Fill'
$header.TextAlign = 'MiddleLeft'
$tlp.Controls.Add($header, 0, 0)
$tlp.SetColumnSpan($header, 5)

# ---- Event Rows ----
$controls = @{}

foreach ($idx in 0..3) {
    $evName = $EVENTS[$idx]
    $row    = $idx + 1

    $lbl           = New-Object System.Windows.Forms.Label
    $lbl.Text      = $evName
    $lbl.Dock      = 'Fill'
    $lbl.TextAlign = 'MiddleLeft'
    $lbl.Font      = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $txt           = New-Object System.Windows.Forms.TextBox
    $txt.ReadOnly  = $true
    $txt.Dock      = 'Fill'
    $txt.BackColor = [System.Drawing.SystemColors]::Window
    $txt.Text      = if ($cfg.$evName.SourcePath) { $cfg.$evName.SourcePath } else { '' }

    $btnBrowse      = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = 'Browse...'
    $btnBrowse.Dock = 'Fill'

    $btnPreview      = New-Object System.Windows.Forms.Button
    $btnPreview.Text = 'Preview'
    $btnPreview.Dock = 'Fill'

    $btnClear           = New-Object System.Windows.Forms.Button
    $btnClear.Text      = 'X'
    $btnClear.Dock      = 'Fill'
    $btnClear.ForeColor = [System.Drawing.Color]::Firebrick

    $tlp.Controls.Add($lbl,        0, $row)
    $tlp.Controls.Add($txt,        1, $row)
    $tlp.Controls.Add($btnBrowse,  2, $row)
    $tlp.Controls.Add($btnPreview, 3, $row)
    $tlp.Controls.Add($btnClear,   4, $row)

    $controls[$evName] = @{ Txt = $txt }

    # --- Browse ---
    $c_ev  = $evName
    $c_txt = $txt
    $c_st  = $statusLabel
    $btnBrowse.Add_Click({
        $ofd        = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Filter = $script:WAV_FILTER
        $ofd.Title  = "Select WAV for $c_ev"
        if ($ofd.ShowDialog() -eq 'OK') {
            $c_txt.Text      = $ofd.FileName
            $c_st.Text       = "$c_ev sound selected. Press Apply to save."
            $c_st.ForeColor  = [System.Drawing.Color]::DimGray
        }
    }.GetNewClosure())

    # --- Preview ---
    $c_txt2 = $txt
    $c_st2  = $statusLabel
    $btnPreview.Add_Click({
        $path = $c_txt2.Text
        if ([string]::IsNullOrEmpty($path) -or -not (Test-Path $path)) {
            $c_st2.Text      = 'Select a valid WAV file first.'
            $c_st2.ForeColor = [System.Drawing.Color]::OrangeRed
            return
        }
        try {
            $sp = New-Object System.Media.SoundPlayer $path
            $sp.Play()
            $c_st2.Text      = 'Previewing...'
            $c_st2.ForeColor = [System.Drawing.Color]::DimGray

            $pt    = New-Object System.Windows.Forms.Timer
            $pt.Interval = 10000
            $c_sp  = $sp
            $c_pt  = $pt
            $c_st3 = $c_st2
            $pt.Add_Tick({
                $c_sp.Stop(); $c_sp.Dispose()
                $c_pt.Stop(); $c_pt.Dispose()
                $c_st3.Text      = 'Ready.'
                $c_st3.ForeColor = [System.Drawing.Color]::DimGray
            }.GetNewClosure())
            $pt.Start()
        } catch {
            $c_st2.Text      = "Preview error: $($_.Exception.Message)"
            $c_st2.ForeColor = [System.Drawing.Color]::Red
        }
    }.GetNewClosure())

    # --- Clear ---
    $c_txt3 = $txt
    $c_ev3  = $evName
    $c_st4  = $statusLabel
    $btnClear.Add_Click({
        $c_txt3.Text     = ''
        $c_st4.Text      = "$c_ev3 cleared. Press Apply to save."
        $c_st4.ForeColor = [System.Drawing.Color]::DimGray
    }.GetNewClosure())
}

# ---- Bottom Bar ----
$bottomPanel      = New-Object System.Windows.Forms.Panel
$bottomPanel.Dock = 'Fill'

$btnApply        = New-Object System.Windows.Forms.Button
$btnApply.Text   = 'Apply'
$btnApply.Dock   = 'Right'
$btnApply.Width  = 90
$btnApply.Height = 30
$btnApply.Font   = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

# Add Apply first so it docks right, then statusLabel fills remaining space
$bottomPanel.Controls.Add($btnApply)
$bottomPanel.Controls.Add($statusLabel)

$tlp.Controls.Add($bottomPanel, 0, 5)
$tlp.SetColumnSpan($bottomPanel, 5)

$form.Controls.Add($tlp)

# ---- Apply Click ----
$btnApply.Add_Click({
    $rows = @{}
    foreach ($e in $script:EVENTS) { $rows[$e] = $controls[$e].Txt.Text }
    $btnApply.Enabled      = $false
    $statusLabel.Text      = 'Applying...'
    $statusLabel.ForeColor = [System.Drawing.Color]::DarkBlue
    $form.Refresh()
    $ok = Invoke-Apply -rows $rows -cfg $cfg -statusLbl $statusLabel -frm $form
    if ($ok) {
        $statusLabel.Text      = 'Applied successfully.'
        $statusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    } else {
        $statusLabel.Text      = 'Applied with errors. See messages above.'
        $statusLabel.ForeColor = [System.Drawing.Color]::OrangeRed
    }
    $btnApply.Enabled = $true
})

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
#endregion
