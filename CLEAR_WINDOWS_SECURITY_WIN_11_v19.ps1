
# CLEAR_WINDOWS_SECURITY_WIN_11_v19 
# Windows Security Cleaner GUI - (PS2EXE)
# ============================

# --- Safe path resolution for script/EXE location ---
try {
    if ($PSScriptRoot -and $PSScriptRoot.Trim() -ne "") {
        $ScriptDir = $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $ScriptDir = [System.IO.Directory]::GetCurrentDirectory()
    }
} catch {
    $ScriptDir = [System.IO.Directory]::GetCurrentDirectory()
}

$LogFile = Join-Path $ScriptDir "Cleaner.log"

# --- Logging ---
function Write-Log {
    param([string]$Message)

    try {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $LogFile -Value "[$timestamp] $Message"
    } catch {
        # If logging fails, do not crash the app
    }

    if ($script:LogBox) {
        try {
            if (Test-Path $LogFile) {
                $script:LogBox.Text = Get-Content $LogFile -Raw
                $script:LogBox.ScrollToEnd()
            }
        } catch {}
    }
    if ($script:StatusText) {
        $script:StatusText.Text = $Message
    }
}

# --- Close Windows Security UI processes (placeholder) ---
function Close-WindowsSecurityUI {
    Write-Log "Close-WindowsSecurityUI: placeholder, no processes closed."
    # TODO: optionally close UI-related processes here
}

# --- Restart helpers ---
function Prompt-Restart {
    $msg   = "A system restart is required to complete the cleanup."
    $title = "Restart Required"

    $result = [System.Windows.MessageBox]::Show($msg, $title, "OKCancel", "Information")

    if ($result -eq "OK") {
        Write-Log "User accepted restart."
        Restart-Computer
    } else {
        Write-Log "User cancelled restart."
    }
}

function Auto-Restart {
    Write-Log "Auto-restart triggered."
    Restart-Computer
}

# --- Status detection (placeholders) ---
function Get-SystemStatus {
    # TODO: Insert your own detection logic here.
    return @{
        Quarantine = $false
        EventLog   = $false
    }
}

# --- WPF UI ---
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Security Cleaner"
        Width="700" Height="650">

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Text="Windows Security Cleaner" FontSize="22" FontWeight="Bold"/>

        <StackPanel Grid.Row="1" Margin="0,15,0,0">
            <TextBlock Text="Detected Status:" FontWeight="Bold"/>
            <TextBlock x:Name="StatusQ"/>
            <TextBlock x:Name="StatusLog"/>
        </StackPanel>

        <StackPanel Grid.Row="2" Margin="0,20,0,0">
            <CheckBox x:Name="ChkQ"   Content="Clear quarantine" IsChecked="True"/>
            <CheckBox x:Name="ChkLog" Content="Clear event log" IsChecked="True"/>
        </StackPanel>

        <StackPanel Grid.Row="3" Margin="0,10,0,0">
            <CheckBox x:Name="ChkDry"  Content="Dry-run (no changes)" IsChecked="False"/>
            <CheckBox x:Name="ChkAuto" Content="Auto-restart after cleanup" IsChecked="False"/>
        </StackPanel>

        <TextBlock Grid.Row="4" Margin="0,10,0,0" TextWrapping="Wrap">
            Dry-run mode simulates all actions and logs what would happen,
            but does not modify anything.
        </TextBlock>

        <StackPanel Grid.Row="5" Margin="0,20,0,0">
            <ProgressBar x:Name="Progress" Height="25" Minimum="0" Maximum="100"/>
            <TextBox x:Name="LogBox" Margin="0,10,0,0" Height="220" TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto" IsReadOnly="True"/>
        </StackPanel>

        <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,15,0,0">
            <Button x:Name="BtnRun"  Content="Run Cleanup" Width="150" Height="40" Margin="10,0"/>
            <Button x:Name="BtnOpen" Content="Open Log Folder" Width="180" Height="40" Margin="10,0"/>
        </StackPanel>

        <TextBlock Grid.Row="7" x:Name="StatusText" Margin="0,10,0,0" FontStyle="Italic" Foreground="Gray"/>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$Xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# --- Bind UI elements ---
$script:StatusQ     = $Window.FindName("StatusQ")
$script:StatusLog   = $Window.FindName("StatusLog")
$script:Progress    = $Window.FindName("Progress")
$script:LogBox      = $Window.FindName("LogBox")
$script:StatusText  = $Window.FindName("StatusText")
$BtnRun             = $Window.FindName("BtnRun")
$BtnOpen            = $Window.FindName("BtnOpen")
$ChkQ               = $Window.FindName("ChkQ")
$ChkLog             = $Window.FindName("ChkLog")
$ChkDry             = $Window.FindName("ChkDry")
$ChkAuto            = $Window.FindName("ChkAuto")

# --- Status UI refresh ---
function Refresh-StatusUI {
    $status = Get-SystemStatus

    if ($status.Quarantine) {
        $script:StatusQ.Text = "Quarantine: PRESENT"
        $script:StatusQ.Foreground = [System.Windows.Media.Brushes]::OrangeRed
    } else {
        $script:StatusQ.Text = "Quarantine: NONE"
        $script:StatusQ.Foreground = [System.Windows.Media.Brushes]::Green
    }

    if ($status.EventLog) {
        $script:StatusLog.Text = "Event Log: HAS ENTRIES"
        $script:StatusLog.Foreground = [System.Windows.Media.Brushes]::OrangeRed
    } else {
        $script:StatusLog.Text = "Event Log: EMPTY"
        $script:StatusLog.Foreground = [System.Windows.Media.Brushes]::Green
    }
}

Refresh-StatusUI

if (Test-Path $LogFile) {
    try {
        $LogBox.Text = Get-Content $LogFile -Raw
        $LogBox.ScrollToEnd()
    } catch {}
}

# --- Cleanup actions (placeholders) ---
$CleanupActions = @{
    ClearQuarantine = {
        Write-Log "TODO: Clear quarantine (insert your logic here)."
        # Insert your own cleanup logic here
    }

    ClearEventLog = {
        Write-Log "TODO: Clear event log (insert your logic here)."
        # Insert your own cleanup logic here
    }
}

# --- Buttons + background execution ---
$BtnOpen.Add_Click({
    try {
        Start-Process explorer.exe $ScriptDir
    } catch {
        Write-Log "Failed to open log folder: $ScriptDir"
    }
})

$BtnRun.Add_Click({
    $script:Progress.Value = 0
    $dry  = $ChkDry.IsChecked
    $auto = $ChkAuto.IsChecked

    Write-Log "=== Cleanup started (dry-run: $dry) ==="

    Close-WindowsSecurityUI

    $steps = @()
    if ($ChkQ.IsChecked)   { $steps += "ClearQuarantine" }
    if ($ChkLog.IsChecked) { $steps += "ClearEventLog" }

    if ($steps.Count -eq 0) {
        Write-Log "No actions selected."
        [System.Windows.MessageBox]::Show("No actions selected.")
        return
    }

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick({
        $script:Progress.Value = ($script:Progress.Value + 5) % 100
    })
    $timer.Start()

    [System.Threading.Tasks.Task]::Run({
        foreach ($s in $steps) {
            Write-Log "Executing: $s"

            if (-not $dry) {
                & $CleanupActions[$s]
                Write-Log "Done: $s"
            } else {
                Write-Log "Dry-run: skipped $s"
            }

            Start-Sleep -Milliseconds 300
        }

        Write-Log "=== Cleanup completed ==="

        $Window.Dispatcher.Invoke({
            $timer.Stop()
            $script:Progress.Value = 100
            Refresh-StatusUI

            if ($auto) {
                Auto-Restart
            } else {
                Prompt-Restart
            }
        })
    })
})

$Window.ShowDialog() | Out-Null