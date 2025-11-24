#!/usr/bin/env bash
set -euo pipefail

# get_site_url.sh
# Prints the GitHub Pages site URL for the repo and checks HTTP status.

OWNER="Ravi-Chandra24"
REPO="Ask-her-Out"
EXPECTED_URL="https://${OWNER}.github.io/${REPO}/"

echo "Repository: ${OWNER}/${REPO}"

SITE_URL=""

if command -v gh >/dev/null 2>&1; then
  echo "Querying GitHub Pages via 'gh' CLI..."
  SITE_URL=$(gh api /repos/${OWNER}/${REPO}/pages --jq '.html_url' 2>/dev/null || true)
  if [[ -z "${SITE_URL}" || "${SITE_URL}" == "null" ]]; then
    echo "gh did not return a pages URL. Falling back to expected URL."
    SITE_URL="$EXPECTED_URL"
  else
    echo "Pages URL (from GitHub API): $SITE_URL"
  fi
else
  echo "'gh' CLI not found. Using expected URL: $EXPECTED_URL"
  SITE_URL="$EXPECTED_URL"
fi

echo "Checking HTTP status for: $SITE_URL"
if command -v curl >/dev/null 2>&1; then
  status=$(curl -s -o /dev/null -w "%{http_code}" "$SITE_URL" || echo "000")
  echo "HTTP status: $status"
  if [[ "$status" -ge 200 && "$status" -lt 400 ]]; then
    echo "Site appears live: $SITE_URL"
  else
    echo "Site not reachable or returns status $status. It may not be published yet."
  fi
else
  echo "curl not available; cannot check HTTP status. Final URL: $SITE_URL"
fi

echo "Done."

# chmod +x publish_all.sh./publish_all.sh --use-https --enable-pages