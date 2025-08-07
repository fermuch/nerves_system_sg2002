#!/bin/sh

# Check if nerves_serial_number exists, if not create it
if ! fw_printenv nerves_serial_number > /dev/null 2>&1; then
  ID=$(uuidgen -r | tr -d '-')
  fw_setenv nerves_serial_number "$ID"
  echo "Setting nerves_serial_number to: $ID"
fi
