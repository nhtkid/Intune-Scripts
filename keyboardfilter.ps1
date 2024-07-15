# Public Kiosk Keyboard Filter Script
# This script configures the Keyboard Filter feature to prevent unauthorized access
# to system settings and keep users within intended applications on public kiosk PCs.

# Define log file path
$logFile = "C:\Windows\Logs\KioskKeyboardFilterLog.txt"

# Function to write log messages
function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
    Write-Host $Message
}

# Function to check if Keyboard Filter feature is installed
function Check-KeyboardFilter {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "Client-KeyboardFilter"
    return $feature.State -eq "Enabled"
}

# Function to install Keyboard Filter feature
function Install-KeyboardFilter {
    Write-Log "Installing Keyboard Filter feature..."
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName "Client-KeyboardFilter" -NoRestart
        Write-Log "Keyboard Filter feature installed successfully."
    }
    catch {
        Write-Log "Error installing Keyboard Filter feature: $_"
    }
}

# Function to enable predefined key filter
function Enable-PredefinedKey($Id) {
    try {
        $predefined = Get-WmiObject -Namespace "root\standardcimv2\embedded" -Class WEKF_PredefinedKey |
            Where-Object { $_.Id -eq $Id }
        
        if ($predefined) {
            $predefined.Enabled = 1
            $predefined.Put() | Out-Null
            Write-Log "Enabled predefined key filter: $Id"
        } else {
            Write-Log "Error: $Id is not a valid predefined key"
        }
    }
    catch {
        Write-Log "Error enabling predefined key filter $Id: $_"
    }
}

# Function to enable custom key filter
function Enable-CustomKey($Id) {
    try {
        $custom = Get-WmiObject -Namespace "root\standardcimv2\embedded" -Class WEKF_CustomKey |
            Where-Object { $_.Id -eq $Id }
        
        if ($custom) {
            $custom.Enabled = 1
            $custom.Put() | Out-Null
            Write-Log "Enabled custom key filter: $Id"
        } else {
            Set-WmiInstance -Namespace "root\standardcimv2\embedded" -Class WEKF_CustomKey -Arguments @{Id=$Id} | Out-Null
            Write-Log "Added custom key filter: $Id"
        }
    }
    catch {
        Write-Log "Error enabling custom key filter $Id: $_"
    }
}

# Main script execution
Write-Log "Script execution started"

try {
    if (-not (Check-KeyboardFilter)) {
        Write-Log "Keyboard Filter feature not found. Installing..."
        Install-KeyboardFilter
    } else {
        Write-Log "Keyboard Filter feature is already installed."
    }

    # Enable critical keyboard filters
    Write-Log "Configuring keyboard filters for public kiosk security..."

    # System-level access prevention
    Enable-PredefinedKey "Ctrl+Alt+Del"
    Enable-PredefinedKey "Windows"
    Enable-PredefinedKey "Ctrl+Esc"
    Enable-CustomKey "Win+X"  # Quick Link menu
    Enable-CustomKey "Win+I"  # Settings
    Enable-CustomKey "Win+R"  # Run dialog
    Enable-CustomKey "Ctrl+Shift+Esc"  # Task Manager

    # Application switching and closing prevention
    Enable-PredefinedKey "Alt+Tab"
    Enable-PredefinedKey "Alt+Esc"
    Enable-CustomKey "Alt+F4"  # Close window

    # Desktop access prevention
    Enable-CustomKey "Win+D"  # Show/Hide desktop
    Enable-CustomKey "Win+M"  # Minimize all windows

    # Other potentially disruptive shortcuts
    Enable-CustomKey "Win+L"  # Lock computer
    Enable-CustomKey "Win+E"  # File Explorer
    Enable-CustomKey "Win+S"  # Search
    Enable-CustomKey "Win+A"  # Action Center
    Enable-CustomKey "PrtScn"  # Print Screen
    Enable-CustomKey "Win+PrtScn"  # Save screenshot
    Enable-CustomKey "Win+Shift+S"  # Snipping tool

    Write-Log "Keyboard filter configuration for public kiosk completed successfully."
}
catch {
    Write-Log "An error occurred during script execution: $_"
}

Write-Log "Script execution finished"
