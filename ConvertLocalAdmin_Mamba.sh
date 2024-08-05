#!/bin/bash

# Get a list of all local users
users=$(dscl . list /Users UniqueID | awk '$2 >= 501 { print $1 }')

# Loop through each user
for user in $users
do
    # Change the user account to Standard
    dseditgroup -o edit -d $user -t user admin

    # Log the action
    echo "$(date): User $user account changed from Admin to Standard" >> /var/log/convert_admin.log
done
