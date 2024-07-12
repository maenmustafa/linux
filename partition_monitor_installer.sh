#!/bin/bash

# Check if a parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <Alert Name>"
    exit 1
fi

ALERT_NAME="$1"

# Define log file
LOGFILE="/var/log/partitionmonitor_install.log"
CUSTOMER_FILE="/root/.customername.txt"
VERSION_FILE="/root/.partitionmonitor_version"

# Log function
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" >> "$LOGFILE"
}

# Save the customer name to a file
echo "$ALERT_NAME" > "$CUSTOMER_FILE"

# Initialize the current version file
echo "1.0.0" > "$VERSION_FILE"

# Creating the partitionmonitor.sh script
log "Creating /partitionmonitor.sh"
cat << 'EOF' > /partitionmonitor.sh
#!/bin/bash
# monitoring tools final script... monitor diskspace

# Set your parameters
thresholdUsage=80
ip4=$(hostname -I | awk '{print $1}')

recipientEmails=("angalerts@an-group.one")
smtpServer="smtp.gmail.com"
smtpPort=587
smtpUsername="notificationrsp@gmail.com"
smtpPassword="niqeibdlwtcmqnch"

# Partitions to monitor:
partitions=("/" "/hana/data" "/hana/log" "/hana/shared" "/usr/sap")

# Function to check disk usage and send email if above threshold
check_disk_space() {
    emailBody=""
    for partition in "${partitions[@]}"; do
        usage=$(df -h "$partition" | awk 'NR==2 {print $5}' | sed 's/%//')
        if [ "$usage" -ge "$thresholdUsage" ]; then
            emailBody+="Disk usage for partition $partition is above $thresholdUsage%. Current usage: $usage%.\n"
        fi
    done
    
    if [ -n "$emailBody" ]; then
        subject="ANG Alerts $(cat /root/.customername.txt): Disk Space Alert from $ip4"
        
        # Join recipients with space
        recipientList=$(IFS=,; echo "${recipientEmails[*]}")
        echo -e "$emailBody" | mailx -v -s "$subject" -r "ANG Alerts <notificationrsp@gmail.com>" -S smtp="smtp://$smtpServer:$smtpPort" -S smtp-use-starttls -S smtp-auth=login -S smtp-auth-user="$smtpUsername" -S smtp-auth-password="$smtpPassword" $recipientList
        
        # Optionally, log this action
        echo "$(date): Disk space alert sent. Details: $emailBody" >> /var/log/disk_space_alert.log
    fi
}

# Function to check for updates and install if available
check_for_updates() {
    current_version=$(cat /root/.partitionmonitor_version)
    remote_version=$(curl -s https://raw.githubusercontent.com/maenmustafa/linux/main/version.txt)

    if [ "$remote_version" != "$current_version" ]; then
        echo "New version available: $remote_version. Updating..."
        wget https://raw.githubusercontent.com/maenmustafa/linux/main/partition_monitor_installer.sh -O /tmp/partition_monitor_installer.sh
        chmod +x /tmp/partition_monitor_installer.sh

        # Read customer name from file
        CustomerName=$(cat /root/.customername.txt)

        /tmp/partition_monitor_installer.sh "$CustomerName"

        # Update the current version file
        echo "$remote_version" > /root/.partitionmonitor_version

        echo "New version $remote_version installed successfully."
    else
        echo "No new version available. Current version: $current_version."
    fi
}

# Check disk space for each partition
check_disk_space

# Check for updates
check_for_updates
EOF

if [ $? -eq 0 ]; then
    log "Successfully created /partitionmonitor.sh"
else
    log "Failed to create /partitionmonitor.sh"
    exit 1
fi

# Make the script executable
log "Setting execute permissions on /partitionmonitor.sh"
chmod +x /partitionmonitor.sh

if [ $? -eq 0 ]; then
    log "Successfully set execute permissions on /partitionmonitor.sh"
else
    log "Failed to set execute permissions on /partitionmonitor.sh"
    exit 1
fi

# Remove existing crontab lines containing /partitionmonitor.sh
log "Removing existing crontab entries for /partitionmonitor.sh"
crontab -l | grep -v '/partitionmonitor.sh' | crontab -

if [ $? -eq 0 ]; then
    log "Successfully removed existing crontab entries for /partitionmonitor.sh"
else
    log "Failed to remove existing crontab entries for /partitionmonitor.sh"
    exit 1
fi

# Add the script to crontab
log "Adding /partitionmonitor.sh to crontab"
(crontab -l 2>/dev/null; echo "* */6 * * * /partitionmonitor.sh") | crontab -

if [ $? -eq 0 ]; then
    log "Successfully added /partitionmonitor.sh to crontab"
else
    log "Failed to add /partitionmonitor.sh to crontab"
    exit 1
fi

log "Installation completed successfully"

# Delete the installation script itself
log "Deleting installation script"
rm -- "$0"

if [ $? -eq 0 ]; then
    log "Successfully deleted installation script"
else
    log "Failed to delete installation script"
    exit 1
fi
