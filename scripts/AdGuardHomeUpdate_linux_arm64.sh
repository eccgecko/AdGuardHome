#!/bin/bash                                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                                
# Check if the script is being run as root, and if not, request sudo privileges                                                                                                                                                                                 
if [ $EUID != 0 ]; then                                                                                                                                                                                                                                         SUDO=sudo
fi

# Set the name of the tarball we want to download and create a $WORKING_DIRECTORY in the $HOME directory for backups and logs, using the date for backup directory names
# !! Change the name of your architecture at TARBALL variable if $ARCH is different from linux_arm64 !!

TARBALL="AdGuardHome_linux_arm64.tar.gz"
DATE=$(date +%Y.%m.%d.%H:%M:%S)
WORKING_DIR="$HOME/my-agh-update"
if [ ! -d "$WORKING_DIR" ]; then
	            mkdir -p "$WORKING_DIR"
fi
LOG_DIR="$WORKING_DIR"
BACKUP_DIR="$WORKING_DIR/$DATE"

# Download the latest release of AdGuardHome
echo "Downloading latest AdGuardHome tarball..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep tag_name | cut -d '"' -f 4) 
DOWNLOAD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/$LATEST_RELEASE/$TARBALL"
if ! wget -q -O "/tmp/$TARBALL" "$DOWNLOAD_URL" 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	            echo "Error: Failed to download AdGuardHome tarball." >&2
		                    exit 1
fi

# Download the checksum file and verify the sha256 checksum of the downloaded tarball
echo "Verifying checksum..."
CHECKSUM_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/$LATEST_RELEASE/checksums.txt"
if ! wget -q -O "/tmp/checksums.txt" "$CHECKSUM_URL" 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
	            echo "Error: Failed to download checksum file." >&2
		                    exit 1
fi

EXPECTED_CHECKSUM=$(grep "$TARBALL" /tmp/checksums.txt | awk '{ print $1 }')
ACTUAL_CHECKSUM=$(sha256sum "/tmp/$TARBALL" | awk '{ print $1 }')

if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
	            echo "Error: Checksum verification failed for $TARBALL." >&2
		                    exit 1
				            else
						                        echo "Checksum verification passed"
fi

# Stop the current running AdGuardHome service and create a backup of the AdGuardHome configuration and data
echo "Stopping AdGuardHome service and creating backup..."
if $SUDO systemctl is-active --quiet AdGuardHome.service; then
           $SUDO systemctl stop AdGuardHome.service 2>> "$LOG_DIR/adguard-update-$DATE.log" || { echo "Error: Failed to stop AdGuardHome service." >&2; exit 1; }
    else
               echo "AdGuardHome service is not running."
fi

if [ ! -d "$BACKUP_DIR" ]; then
	            mkdir -p "$BACKUP_DIR"
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
echo "Starting the AdGuardHome service"
if ! $SUDO systemctl start AdGuardHome.service 2>> "$LOG_DIR/adguard-update-$DATE.log" ; then
           echo "Error: Failed to start AdGuardHome service." >&2
               exit 1
fi
