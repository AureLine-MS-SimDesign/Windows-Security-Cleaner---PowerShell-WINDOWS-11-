# --- Elevation check ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process pwsh.exe -Verb RunAs -ArgumentList "-NoProfile -File `"$PSCommandPath`""
    exit
}

# --- Paths ---
$ScriptDir = Split-Path -Parent $PSCommandPath
$LogFile   = Join-Path $ScriptDir "DWDH.log"

$Defender      = 'C:\ProgramData\Microsoft\Windows Defender'
$Quarantine    = Join-Path $Defender 'Quarantine'
$Scans         = Join-Path $Defender 'Scans'
$Service       = Join-Path $Scans 'History\Service'
$dbPattern     = Join-Path $Scans 'mpenginedb.db*'
$TaskName      = 'DWDH'

# --- Logging ---
# Uwaga: $tbLog zostanie zainicjalizowane dopiero po stworzeniu UI,
# ale funkcja Log może być wywoływana później – dlatego sprawdzamy, czy istnieje.
function Log {
    param([string]$msg)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LogFile -Value "[$timestamp] $msg"

    if ($script:tbLog) {
        $script:tbLog.Text = Get-Content $LogFile -Raw
        $script:tbLog.ScrollToEnd()
    }
}

# --- Status detection ---
function Get-Status {
    @{
        AV          = Test-Path $Service
        Quarantine  = Test-Path $Quarantine
        CFA         = (Get-ChildItem $dbPattern -ErrorAction SilentlyContinue).Count -gt 0
        Task        = (schtasks /query /tn $TaskName 2>$null) -ne $null
    }
}

# --- Cleanup actions ---
$CleanupActions = @{
    ClearAV         = { Remove-Item -Path $Service    -Recurse -Force -ErrorAction SilentlyContinue }
    ClearQuarantine = { Remove-Item -Path $Quarantine -Recurse -Force -ErrorAction SilentlyContinue }
    ClearCFA        = { Get-ChildItem $dbPattern -ErrorAction SilentlyContinue | Remove-Item -Force }
    RemoveTask      = { schtasks /delete /f /tn $TaskName | Out-Null }
}

# --- WPF UI ---
Add-Type -AssemblyName PresentationFramework

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Defender History Cleaner"
        Width="650" Height="600">

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Text="Windows Defender History Cleaner" FontSize="22" FontWeight="Bold"/>

        <StackPanel Grid.Row="1" Margin="0,15,0,0">
            <TextBlock Text="Status elementów:" FontWeight="Bold"/>
            <TextBlock x:Name="stAV"/>
            <TextBlock x:Name="stQ"/>
            <TextBlock x:Name="stCFA"/>
            <TextBlock x:Name="stTask"/>
        </StackPanel>

        <StackPanel Grid.Row="2" Margin="0,20,0,0">
            <CheckBox x:Name="cbAV" Content="Clear AV detection history" IsChecked="True"/>
            <CheckBox x:Name="cbQ"  Content="Clear Quarantine" IsChecked="True"/>
            <CheckBox x:Name="cbCFA" Content="Clear Controlled Folder Access history" IsChecked="True"/>
            <CheckBox x:Name="cbTask" Content="Remove scheduled task after run" IsChecked="True"/>
        </StackPanel>

        <StackPanel Grid.Row="3" Margin="0,20,0,0">
            <CheckBox x:Name="cbDry" Content="Dry-run mode (test only, no changes)" IsChecked="False"/>
        </StackPanel>

        <TextBlock Grid.Row="4" Margin="0,10,0,0" TextWrapping="Wrap">
            Dry-run oznacza, że skrypt wykona test działania i zapisze w logu,
            co *by* zrobił, ale nie usunie żadnych plików ani wpisów.
        </TextBlock>

        <StackPanel Grid.Row="5" Margin="0,20,0,0">
            <ProgressBar x:Name="pb" Height="25" Minimum="0" Maximum="100"/>
            <TextBox x:Name="tbLog" Margin="0,10,0,0" Height="200" TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto" IsReadOnly="True"/>
        </StackPanel>

        <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,20,0,0">
            <Button x:Name="btnRun" Content="Run Cleanup" Width="150" Height="40" Margin="10,0"/>
            <Button x:Name="btnOpen" Content="Otwórz folder logów" Width="180" Height="40" Margin="10,0"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$Xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# --- Bind UI elements ---
$script:stAV   = $Window.FindName("stAV")
$script:stQ    = $Window.FindName("stQ")
$script:stCFA  = $Window.FindName("stCFA")
$script:stTask = $Window.FindName("stTask")
$script:pb     = $Window.FindName("pb")
$script:tbLog  = $Window.FindName("tbLog")
$btnRun        = $Window.FindName("btnRun")
$btnOpen       = $Window.FindName("btnOpen")
$cbAV          = $Window.FindName("cbAV")
$cbQ           = $Window.FindName("cbQ")
$cbCFA         = $Window.FindName("cbCFA")
$cbTask        = $Window.FindName("cbTask")
$cbDry         = $Window.FindName("cbDry")

# --- Status UI refresh ---
function Refresh-StatusUI {
    $status = Get-Status
    $script:stAV.Text   = "AV history: "      + ($status.AV         ? "ISTNIEJE" : "BRAK")
    $script:stQ.Text    = "Quarantine: "      + ($status.Quarantine ? "ISTNIEJE" : "BRAK")
    $script:stCFA.Text  = "CFA DB: "          + ($status.CFA        ? "ISTNIEJE" : "BRAK")
    $script:stTask.Text = "Scheduled Task: "  + ($status.Task       ? "ISTNIEJE" : "BRAK")
}

# --- Initial status + log preview ---
Refresh-StatusUI

if (Test-Path $LogFile) {
    $tbLog.Text = Get-Content $LogFile -Raw
    $tbLog.ScrollToEnd()
}

# --- Button: Open log folder ---
$btnOpen.Add_Click({
    Start-Process explorer.exe $ScriptDir
})

# --- Button: Run cleanup ---
$btnRun.Add_Click({
    $pb.Value = 0
    $dry = $cbDry.IsChecked

    Log "=== Run started (dry-run: $dry) ==="

    $steps = @()

    if ($cbAV.IsChecked)   { $steps += "ClearAV" }
    if ($cbQ.IsChecked)    { $steps += "ClearQuarantine" }
    if ($cbCFA.IsChecked)  { $steps += "ClearCFA" }
    if ($cbTask.IsChecked) { $steps += "RemoveTask" }

    if ($steps.Count -eq 0) {
        Log "No actions selected. Aborting."
        [System.Windows.MessageBox]::Show("Brak wybranych akcji do wykonania.")
        return
    }

    $stepCount = $steps.Count
    $i = 0

    foreach ($s in $steps) {
        $i++
        $pb.Value = ($i / $stepCount) * 100

        Log "Executing: $s"

        if (-not $dry) {
            & $CleanupActions[$s]
            Log "Done: $s"
        }
        else {
            Log "Dry-run: skipped $s"
        }

        Start-Sleep -Milliseconds 300
    }

    Refresh-StatusUI
    Log "=== Run completed ==="
})

$Window.ShowDialog() | Out-Null
