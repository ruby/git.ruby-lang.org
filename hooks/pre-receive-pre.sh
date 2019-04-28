#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.pre.git/hooks/pre-receive`.
# The ruby.pre repository is just a sandbox, and any commit isn't pushed to it automatically.
# Its outputs are logged to `/tmp/pre-receive-pre.log`.

# script parameters
ruby_git="/var/git/ruby.git"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

echo "[$$] ### Start ($(date)) ###"
echo "[$$] ==> args: $*"

echo "[$$] ==> prohibit merge commits ($(date))"
$ruby_commit_hook/bin/prohibit-merge-commits.rb $* || exit 1

echo "[$$] ==> check email ($(date))"
$ruby_commit_hook/bin/check-email.rb $* || exit 1

echo "[$$] ### End ($(date)) ###"; echo
