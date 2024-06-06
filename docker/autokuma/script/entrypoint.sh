#!/usr/bin/env bash
echo "Starting AutoKuma script"

# Run checks for status page
status_page_missing=$(kuma \
  --url "${AUTOKUMA__KUMA__URL}" \
  --username "${AUTOKUMA__KUMA__USERNAME}" \
  --password "${AUTOKUMA__KUMA__PASSWORD}" \
  status-page get "${STATUS_PAGE_SLUG}")

if [[ "${status_page_missing}" ]]; then
  echo "Status page ${STATUS_PAGE_SLUG} does not exist, creating it:"
else
  echo "Status page ${STATUS_PAGE_SLUG} already exists"
fi

# Run main process
autokuma
