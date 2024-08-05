#!/bin/bash

# Script to convert the admin user to a standard user after Intune enrollment

# Set log file path
LOG_FILE="/var/log/admin_to_standard_conversion.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Create log file if it doesn't exist
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "Starting admin to standard user conversion script"

# Get the name of the user (assumed to be admin)
user=$(dscl . list /Users UniqueID | awk '$2 >= 500 {print $1; exit}')

log "User identified: $user"

# Remove user from admin group
dseditgroup -o edit -d "$user" -t user admin
log "Removed $user from admin group"

log "Conversion of $user to a standard user completed"
log "Script execution completed"
