#!/usr/bin/env bash
set -euo pipefail

# publish_all.sh
# Helper to add/commit/push site files and enable GitHub Pages.
# Usage: ./publish_all.sh [--use-https] [--enable-pages] [--no-push] [--message "msg"]

OWNER="Ravi-Chandra24"
REPO="Ask-her-Out"
BRANCH="main"
FILES=(index.html ask_her_out.html schedule.html git.py)
COMMIT_MSG="Prepare site for GitHub Pages"
USE_HTTPS=false
ENABLE_PAGES=false
NO_PUSH=false

print_help(){
  cat <<EOF
Usage: $0 [options]
Options:
  --use-https       Set remote to HTTPS (https://github.com/OWNER/REPO.git) before push
  --enable-pages     Attempt to enable GitHub Pages for the repo (requires 'gh' or GH_TOKEN)
  --no-push          Do everything except push to the remote
  --message "msg"    Commit message to use (default: "$COMMIT_MSG")
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --use-https) USE_HTTPS=true; shift ;;
    --enable-pages) ENABLE_PAGES=true; shift ;;
    --no-push) NO_PUSH=true; shift ;;
    --message) COMMIT_MSG="$2"; shift 2 ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "Unknown arg: $1"; print_help; exit 1 ;;
  esac
done

echo "Repository: $OWNER/$REPO"
echo "Branch: $BRANCH"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This directory is not a git repository. Run this from the repo root." >&2
  exit 1
fi

echo "Git status (short):"
git status --porcelain || true

echo "Checking git user config..."
git config user.name || echo "user.name not set"
git config user.email || echo "user.email not set"

echo "Staging files: ${FILES[*]}"
git add -- ${FILES[@]}

STAGED=$(git diff --cached --name-only || true)
if [[ -z "$STAGED" ]]; then
  echo "No staged changes to commit."
else
  echo "Staged files:\n$STAGED"
  git commit -m "$COMMIT_MSG" || echo "No commit made (maybe nothing changed)."
fi

if $USE_HTTPS; then
  HTTPS_URL="https://github.com/${OWNER}/${REPO}.git"
  echo "Setting origin to HTTPS: $HTTPS_URL"
  git remote set-url origin "$HTTPS_URL"
fi

if $NO_PUSH; then
  echo "--no-push set: skipping push step."
else
  echo "Pushing to origin $BRANCH..."
  if git rev-parse --verify --quiet origin/${BRANCH} >/dev/null; then
    git push origin "$BRANCH"
  else
    # create upstream
    git push -u origin "$BRANCH"
  fi
fi

SITE_URL="https://${OWNER}.github.io/${REPO}/"
echo "Expected Pages URL: $SITE_URL"

if $ENABLE_PAGES; then
  echo "Attempting to enable GitHub Pages..."
  if command -v gh >/dev/null 2>&1; then
    echo "Using gh CLI to enable Pages (requires gh auth)."
    # Build JSON safely and pass it so variable expansion works
    GH_PAYLOAD=$(printf '{"branch":"%s","path":"/"}' "$BRANCH")
    gh api -X PUT /repos/${OWNER}/${REPO}/pages -f source="${GH_PAYLOAD}" || echo "gh api call failed"
    echo "You can check status at: https://github.com/${OWNER}/${REPO}/settings/pages"
  elif [[ -n "${GH_TOKEN:-}" ]]; then
    echo "Using GH_TOKEN to call GitHub API"
    # Build JSON payload safely to avoid quoting problems
    DATA=$(printf '{"source":{"branch":"%s","path":"/"}}' "$BRANCH")
    curl -sS -X PUT -H "Authorization: token ${GH_TOKEN}" -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${OWNER}/${REPO}/pages" -d "$DATA" || echo "curl call failed"
    echo "Check: https://github.com/${OWNER}/${REPO}/settings/pages"
  else
    echo "Neither 'gh' CLI nor GH_TOKEN available; open the Pages settings in your browser to enable Pages:" 
    echo "https://github.com/${OWNER}/${REPO}/settings/pages"
  fi
fi

echo "Done. Visit: $SITE_URL (it may take a minute to provision HTTPS)"

# --- Site URL detection and check (combined from get_site_url.sh)
echo "\nDetecting Pages URL..."
SITE_URL=""
if command -v gh >/dev/null 2>&1; then
  echo "Querying GitHub Pages via 'gh' CLI..."
  SITE_URL=$(gh api /repos/${OWNER}/${REPO}/pages --jq '.html_url' 2>/dev/null || true)
  if [[ -z "${SITE_URL}" || "${SITE_URL}" == "null" ]]; then
    echo "gh did not return a pages URL. Falling back to expected URL."
    SITE_URL="https://${OWNER}.github.io/${REPO}/"
  else
    echo "Pages URL (from GitHub API): $SITE_URL"
  fi
else
  echo "'gh' CLI not found. Using expected URL: https://${OWNER}.github.io/${REPO}/"
  SITE_URL="https://${OWNER}.github.io/${REPO}/"
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

echo "Finished publish + URL check."
