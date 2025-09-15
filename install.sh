#!/bin/bash
# Installation for rock-pi 4c
# Not tested on any other rockpi units

# Check if the script is running as root (EUID 0)
if (( EUID != 0 )); then
  echo "This script must be run with root privileges. Please use sudo and try again." >&2
  exit 1
fi

# Check if DTC is installed, and install it if not
if ! command -v dtc > /dev/null 2>&1
then
    echo "Installing device tree compiler from apt"
    apt update
    apt install -y device-tree-compiler
fi

# Compile the device driver
echo "Compiling the driver"
dtc -O dtb -o rockchip-pwm-gpio.dtbo -b 0 -@ rockchip-pwm-gpio.dts

# Copy driver to system directory
cp rockchip-pwm-gpio.dtbo /boot/dtb/rockchip/overlay/

# Enable the overlay
ENVFILE="/boot/dietpiEnv.txt"
grep -qxF "overlay_prefix=rockchip" "$ENVFILE" || echo "overlay_prefix=rockchip" | tee -a "$ENVFILE"
grep -qxF "overlays=pwm-gpio" "$ENVFILE"     || echo "overlays=pwm-gpio"     | tee -a "$ENVFILE"

# Create the digital group
groupadd -f digital

# Make scripts executable
chmod +x pwmset
chmod +x pwmsts
chmod +x pwm-fan-startup.sh

# Install binaries to be user bin
cp pwmset /usr/local/bin/
cp pwmsts /usr/local/bin/

# Add startup script to post boot
cp pwm-fan-startup.sh /var/lib/dietpi/postboot.d/

# Add current user to digital group
target_user="${SUDO_USER:-$USER}"
if id -u "$target_user" >/dev/null 2>&1; then
  usermod -a -G digital "$target_user"
  echo "Added user '$target_user' to group 'digital'."
else
  echo "WARNING: User '$target_user' not found; skipped group assignment."
fi

echo "Installed pwm scripts successfully"

# Reboot the system if the user wants - otherwise warn that changes won't be valid until a reboot
read -p "Do you want to reboot the system now? (y/n): " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    reboot
else
    echo "WARNING: You chose not to reboot. Some changes may not take effect until you do."
fi