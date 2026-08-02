#!/bin/bash

# Step 2: Install rclone, set up its config file and log in to Google Drive.

SCRIPT_DIR="$(dirname "$0")"

# Cache the sudo authentication so the user enters the password only once.
sudo -v

# Install unzip if it is missing (rclone's installer needs it).
if ! command -v unzip >/dev/null 2>&1
then
	echo "Unzip not found. Installing it"
	sudo apt update
	sudo apt install -y unzip
fi

# Install rclone only if it is missing.
if ! command -v rclone >/dev/null 2>&1
then
	echo "rclone not found. Installing it..."

	# First try the distro package (fast, uses the local Ubuntu mirror).
	sudo apt update
	sudo apt install -y rclone

	# If the binary is still missing, dpkg may think rclone is installed while
	# its files are actually gone. Force a reinstall to put the binary back.
	if ! command -v rclone >/dev/null 2>&1
	then
		echo "rclone binary missing. Reinstalling the package..."
		sudo apt install --reinstall -y rclone
	fi

	# Last resort: the official installer. Wrapped in a 120 second time limit
	# so it can never hang forever if the download host is slow.
	if ! command -v rclone >/dev/null 2>&1
	then
		echo "Trying the official rclone installer (up to 120s)..."
		curl -fsSL --max-time 120 https://rclone.org/install.sh | sudo timeout 120 bash
	fi

	# Make sure rclone is really installed before going on.
	if ! command -v rclone >/dev/null 2>&1
	then
		echo "rclone installation failed. Check your internet connection and run the script again."
		exit 1
	fi

	echo "rclone installed: $(rclone version | head -n 1)"
else
	echo "rclone found: $(rclone version | head -n 1)"
fi

# Set up the rclone config from the template if it is not there yet.
# The template ships next to this script as rclone.conf.txt.
RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"
TEMPLATE_CONFIG="$SCRIPT_DIR/rclone.conf.txt"

# Ensure config directory exists
mkdir -p "$HOME/.config/rclone"

if [ -f "$RCLONE_CONFIG" ] && [ -s "$RCLONE_CONFIG" ]; then
	echo "rclone config already exists. Skipping setup"
else
	echo "Setting up rclone..."

	if [ -f "$TEMPLATE_CONFIG" ] && [ -s "$TEMPLATE_CONFIG" ]
	then
		cp "$TEMPLATE_CONFIG" "$RCLONE_CONFIG"

		if [ $? -eq 0 ]; then
		    echo "Template config copied"
		else
		    echo "Failed to copy"
		fi
	else
		echo "Template config not found:$TEMPLATE_CONFIG"
		exit 1
	fi
fi

# Make sure we are online before talking to Google Drive.
if ! ping -c 1 google.com >/dev/null 2>&1; then
	echo "Error: NO internet connection"
	exit 1
fi

# Check that rclone can reach Google Drive, and fix the token if needed.
OUTPUT=$(rclone lsd gdrive: 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "rclone authenticated and working."

elif echo "$OUTPUT" | grep -qi "empty token\|no token found\|token not found\|please run rclone config"; then
    echo "No auth token found. Starting fresh OAuth login..."
    pkill -f "rclone authorize" 2>/dev/null
    rm -f /tmp/rclone_auth.log
    sleep 1
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WSL detected. Handling browser manually..."
        rclone authorize "drive" 2>&1 | tee /tmp/rclone_auth.log &
        RCLONE_PID=$!
        for i in $(seq 1 30); do
            URL=$(grep -o 'http://127.0.0.1:[0-9]*/auth[^ ]*' /tmp/rclone_auth.log 2>/dev/null)
            if [ -n "$URL" ]; then
                echo "Opening browser..."
                cmd.exe /c start "" "$URL"
                break
            fi
            sleep 1
        done
        wait $RCLONE_PID
        TOKEN=$(grep -o '{.*}' /tmp/rclone_auth.log | tail -1)
    else
        echo "Linux desktop detected. rclone will open browser automatically..."
        TOKEN=$(rclone authorize "drive" 2>&1 | tee /tmp/rclone_auth.log | grep -o '{.*}' | tail -1)
    fi
    if [ -z "$TOKEN" ]; then
        echo "Failed to capture token."
        exit 1
    fi
    rclone config update gdrive token="$TOKEN"
    echo "Token saved successfully."

elif echo "$OUTPUT" | grep -qi "invalid_grant\|token has been expired\|token is expired\|refresh_token"; then
    echo "Token expired. Reconnecting..."
    pkill -f "rclone authorize" 2>/dev/null
    rm -f /tmp/rclone_auth.log
    sleep 1
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WSL detected. Handling browser manually..."
        rclone authorize "drive" 2>&1 | tee /tmp/rclone_auth.log &
        RCLONE_PID=$!
        for i in $(seq 1 30); do
            URL=$(grep -o 'http://127.0.0.1:[0-9]*/auth[^ ]*' /tmp/rclone_auth.log 2>/dev/null)
            if [ -n "$URL" ]; then
                echo "Opening browser..."
                cmd.exe /c start "" "$URL"
                break
            fi
            sleep 1
        done
        wait $RCLONE_PID
        TOKEN=$(grep -o '{.*}' /tmp/rclone_auth.log | tail -1)
    else
        echo "Linux desktop detected. rclone will open browser automatically..."
        TOKEN=$(rclone authorize "drive" 2>&1 | tee /tmp/rclone_auth.log | grep -o '{.*}' | tail -1)
    fi
    if [ -z "$TOKEN" ]; then
        echo "Failed to capture token."
        exit 1
    fi
    rclone config update gdrive token="$TOKEN"
    echo "Token saved successfully."

elif echo "$OUTPUT" | grep -qi "timeout\|no route\|network"; then
    echo "Network/internet issue."
    exit 1

elif echo "$OUTPUT" | grep -qi "not found in config\|section"; then
    echo "Config error - remote 'gdrive' missing from rclone.conf (check rclone.conf.txt)."
    exit 5

else
    echo "Unknown error: $OUTPUT"
    exit 1
fi

echo "rclone setup complete."
