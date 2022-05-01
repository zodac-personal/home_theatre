#!/bin/bash

################
# Main execution
################

# Run script to update config based on environment variables in separate thread
/var/environment.sh &

# Run default init
/init
