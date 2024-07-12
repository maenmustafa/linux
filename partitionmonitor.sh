#!/bin/bash
# monitoring tools final script... monitor diskspace

# Set your parameters
thresholdUsage=90
ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1);

recipientEmails=("angalerts@an-group.one")
smtpServer="smtp.gmail.com"
smtpPort=587
smtpUsername="notificationrsp@gmail.com"
smtpPassword="niqeibdlwtcmqnch"

# Partitions to monitor:
partitions=("/" "/usr/sap")

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
        subject="ANG Alerts Ensinger SLD : Disk Space Alert from $ip4"
        
        # Join recipients with space
        recipientList=$(IFS=,; echo "${recipientEmails[*]}")
        # change ANG Alert to the customer Name alert
        echo -e "$emailBody" | mailx -v -s "$subject" -r "ANG Alerts <notificationrsp@gmail.com>" -S smtp="smtp://$smtpServer:$smtpPort" -S smtp-use-starttls -S smtp-auth=login -S smtp-auth-user="$smtpUsername" -S smtp-auth-password="$smtpPassword" $recipientList
        
        # Optionally, log this action
        echo "$(date): Disk space alert sent. Details: $emailBody" >> /var/log/disk_space_alert.log
    fi
}

# Check disk space for each partition
check_disk_space

