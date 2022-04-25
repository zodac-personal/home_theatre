#!/bin/bash

# Function to post an ONLINE update to discord with timestamp
startup() {
  curl -X POST \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data "{\"content\": \"Emby server ONLINE: $(date)\"}" \
  "${DISCORD_ONLINE_WEBHOOK_URL}"
}

# Function to post an OFFLINE update to discord with timestamp
shutdown() {
  curl -X POST \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data "{\"content\": \"Emby server OFFLINE: $(date)\"}" \
    "${DISCORD_OFFLINE_WEBHOOK_URL}"
}

################
# Main execution
################

startup

# Trap SIGTERM, and run 'true', which allows the process to pass the 'wait' command later and we can manually specify our shutdown
# We use this instead of [trap 'shutdown' SIGTERM] as it should also handle unexpected container exits too
trap 'true' SIGTERM

# Run default init (retrieved from image using 'docker inspect')
/init &

# Wait for process to die or be killed
wait "${!}"

shutdown
