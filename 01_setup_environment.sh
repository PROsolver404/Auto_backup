#!/bin/bash

# Step 1: Detect the environment and make sure a browser opener is available.
# rclone needs to open a browser during login, so this prepares the right tool
# for WSL, a Linux desktop, or a headless machine.

if grep -qi microsoft /proc/version 2>/dev/null; then
	ENV_TYPE="wsl"
elif [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
	ENV_TYPE="linux_desktop"
else
	ENV_TYPE="headless"
fi

echo "Environment detected: " "$ENV_TYPE"

# Install the browser tool based on environment

if [ "$ENV_TYPE" = "wsl" ]; then
    echo "Checking browser opener for WSL..."
    if command -v cmd.exe >/dev/null 2>&1; then
        echo "cmd.exe found. Browser opening ready."
    elif command -v powershell.exe >/dev/null 2>&1; then
        echo "powershell.exe found. Browser opening ready."
    else
        echo "No Windows browser opener found. URL will be printed manually."
    fi

elif [ "$ENV_TYPE" = "linux_desktop" ]; then

	echo "Checking xdg-open"
	if ! command -v xdg-open >/dev/null 2>&1; then
		sudo apt install -y xdg-utils
		if command -v xdg-open >/dev/null 2>&1; then
			echo "xdg-utils installed success."
		else
			echo "xdg-open install failed."
			exit 1
		fi
	else
		echo "xdg-open already present."
	fi

elif [ "$ENV_TYPE" = "headless" ]; then
	echo "Headless environment. No browser tool needed."
	echo "Auth URL will be printed for manual opening."
fi
