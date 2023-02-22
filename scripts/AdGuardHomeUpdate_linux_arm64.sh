#!/bin/bash                                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                                
# Check if the script is being run as root, and if not, request sudo privileges when required                                                                                                                                                                                 
if [ $EUID != 0 ]; then
SUDO=sudo
fi

# Set variables, such as the  name of the tarball we want to download, create a $WORKING_DIRECTORY in the $HOME directory for backups and logs,
# using the date for backup directory names. Get latest version number from github and set download url
#
#
## !! WARNING !! If you are NOT running arm64 then you MUST change the name of the TARBALL variable!
## !! It must match your $ARCH in the format as they are named on https://github.com/AdguardTeam/AdGuardHome/releases/ !!
## !! use 'uname -m' to find out what $ARCH you're running !!

TARBALL="AdGuardHome_linux_arm64.tar.gz"
DATE=$(date +%Y.%m.%d.%H:%M:%S)
WORKING_DIR="$HOME/my-agh-update"
LOG_DIR="$WORKING_DIR"
BACKUP_DIR="$WORKING_DIR/$DATE"
LATEST_RELEASE=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep tag_name | cut -d '"' -f 4) 
DOWNLOAD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/$LATEST_RELEASE/$TARBALL"
CHECKSUM_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/$LATEST_RELEASE/checksums.txt"

# Create the $WORKING_DIR and $BACKUP DIR if they don't already exist
if [ ! -d "$WORKING_DIR" ]; then
	mkdir -p "$WORKING_DIR"
fi

if [ ! -d "$BACKUP_DIR" ]; then
	mkdir -p "$BACKUP_DIR"
fi


# Download the latest release of AdGuardHome
echo "Downloading latest AdGuardHome tarball..."
if ! wget -q -O "/tmp/$TARBALL" "$DOWNLOAD_URL" 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	echo "Error: Failed to download AdGuardHome tarball." >&2
	exit 1
fi


# Download the checksum file and verify the sha256 checksum of the downloaded tarball
echo "Verifying checksum..."
if ! wget -q -O "/tmp/checksums.txt" "$CHECKSUM_URL" 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	echo "Error: Failed to download checksum file." >&2
	exit 1
fi
EXPECTED_CHECKSUM=$(grep "$TARBALL" /tmp/checksums.txt | awk '{ print $1 }')
ACTUAL_CHECKSUM=$(sha256sum "/tmp/$TARBALL" | awk '{ print $1 }')

if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
	echo "Error: Checksum verification failed for $TARBALL!" >&2
	exit 1
		else echo "Checksum verification passed!"
fi


# Stop the current running AdGuardHome service and create a backup of the AdGuardHome configuration and data
echo "Stopping AdGuardHome service and creating backup..."
if $SUDO systemctl is-active --quiet AdGuardHome.service; then
	$SUDO systemctl stop AdGuardHome.service 2>> "$LOG_DIR/adguard-update-$DATE.log" || { echo "Error: Failed to stop AdGuardHome service." >&2; exit 1; }
	else echo "AdGuardHome service is not running."
fi



if ! $SUDO cp /opt/AdGuardHome/AdGuardHome.yaml "$BACKUP_DIR" 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	echo "Error: Failed to create backup of AdGuardHome configuration file." >&2
	exit 1
fi

if ! $SUDO cp -r /opt/AdGuardHome/data "$BACKUP_DIR" 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	echo "Error: Failed to create backup of AdGuardHome data directory." >&2
	exit 1
fi


# Extract the downloaded tarball and copy the new AdGuardHome binary to /opt/AdGuardHome
echo "Extracting into /tmp/ and and installing updated AdGuardHome binary..."
if ! tar -zxvf "/tmp/$TARBALL" -C /tmp/ 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	echo "Error: Failed to extract AdGuardHome tarball." >&2
	exit 1
fi

if ! $SUDO cp /tmp/AdGuardHome/AdGuardHome /opt/AdGuardHome/ 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	echo "Error: Failed to copy new AdGuardHome binary to /opt/AdGuardHome/." >&2
	exit 1
fi

# Start the AdGuardHome service
echo "Starting the AdGuardHome service..."
if ! $SUDO systemctl start AdGuardHome.service 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	echo "Error: Failed to start AdGuardHome service." >&2
	exit 1
		else sleep 5 # Wait for service to start up
		if $SUDO systemctl is-active --quiet AdGuardHome.service; then echo "AdGuardHome service started successfully!"
		else echo "Error: AdGuardHome service failed to start." >&2
		exit 1
		fi
fi

echo "AdGuardHome update complete!" # Print completion message
