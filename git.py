#!/usr/bin/env python3
"""
Simple helper script to run the git commands to publish this repo to GitHub Pages.

It will:
 - git add the relevant files
 - git commit (if there are staged changes)
 - add an `origin` remote if missing (uses the likely repo URL)
 - git push origin main

Note: Pushing requires that you have permission and authentication (SSH key or
HTTPS credentials) set up for GitHub on this machine.
"""

import subprocess
import sys

REPO_OWNER = "Ravi-Chandra24"
REPO_NAME = "Ask-her-Out"
# By default include the script itself so it gets pushed when created locally
FILES = ["index.html", "ask_her_out.html", "schedule.html", "git.py"]
COMMIT_MSG = "Prepare site for GitHub Pages"


def run(cmd, check=True, capture=False):
    print("$", " ".join(cmd))
    try:
        if capture:
            return subprocess.check_output(cmd, stderr=subprocess.STDOUT).decode().strip()
        else:
            subprocess.check_call(cmd)
            return None
    except subprocess.CalledProcessError as e:
        out = None
        try:
            out = e.output.decode()
        except Exception:
            out = str(e)
        print("Command failed:", out, file=sys.stderr)
        if check:
            sys.exit(e.returncode)
        return None


def inside_git_repo():
    # Use subprocess.run directly so we don't depend on run() calling sys.exit
    p = subprocess.run(["git", "rev-parse", "--is-inside-work-tree"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.returncode == 0


def ensure_origin():
    # Use subprocess.run to check for an existing origin without exiting the script
    p = subprocess.run(["git", "remote", "get-url", "origin"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode == 0:
        url = p.stdout.decode().strip()
        print("origin remote configured:", url)
        return True
    else:
        # Add origin using the SSH URL (user can change to HTTPS if desired)
        ssh_url = f"git@github.com:{REPO_OWNER}/{REPO_NAME}.git"
        print("No origin remote found. Adding origin ->", ssh_url)
        run(["git", "remote", "add", "origin", ssh_url])
        return True


def parse_args():
    import argparse
    p = argparse.ArgumentParser(description="Simple git helper to add/commit/push site files")
    p.add_argument("-m", "--message", default=COMMIT_MSG, help="Commit message to use")
    p.add_argument("--all", action="store_true", help="Run `git add -A` to add all changes")
    p.add_argument("--no-push", action="store_true", help="Do everything except push to remote")
    p.add_argument("--remote", default="origin", help="Remote name to push to")
    p.add_argument("--branch", default="main", help="Branch name to push to")
    p.add_argument("--dry-run", action="store_true", help="Show commands but don't execute push/commit")
    return p.parse_args()


def main():
    if not inside_git_repo():
        print("This directory is not a git repository. Initialize or run from repo root.")
        sys.exit(1)

    args = parse_args()

    # Stage files
    if args.all:
        run(["git", "add", "-A"])
    else:
        run(["git", "add"] + FILES)

    # Check for staged files
    staged = run(["git", "diff", "--cached", "--name-only"], capture=True)
    if not staged:
        print("No staged changes to commit.")
    else:
        print("Staged files:\n", staged)
        if args.dry_run:
            print("Dry-run: would commit with message:\n", args.message)
        else:
            run(["git", "commit", "-m", args.message])

    # Ensure origin remote exists
    ensure_origin()

    # Push to origin branch unless disabled
    if args.no_push:
        print("--no-push set: skipping push step.")
    else:
        print(f"Pushing to {args.remote} {args.branch}...")
        if args.dry_run:
            print("Dry-run: would run push command")
        else:
            run(["git", "push", args.remote, args.branch])


if __name__ == "__main__":
    main()
