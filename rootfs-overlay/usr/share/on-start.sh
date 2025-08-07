#!/bin/sh

# Check if nerves_serial_number exists, if not create it
if ! fw_printenv nerves_serial_number > /dev/null 2>&1; then
  UUID=$(uuidgen -r)
  ID=""
  for char in $(echo "$UUID" | fold -w1); do
    if [ "$char" != "-" ]; then
      ID="$ID$char"
    fi
  done
  fw_setenv nerves_serial_number "$ID"
  echo "Setting nerves_serial_number to: $ID"
fi
