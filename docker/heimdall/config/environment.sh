#!/bin/bash
# Script to update the '/config/www/.env' file with values from environment variables
# Since the '/config/www/.env' file is created during the /init script, and that script never ends, we run this script
# first, but in a background process.

# Sleep to allow the /init script to finish
sleep 10

# After init is complete, override the value of the application title
sed -i "s|APP_NAME=.*|APP_NAME=\"${DASHBOARD_TITLE}\"|g" /config/www/.env
