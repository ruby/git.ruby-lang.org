#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.git/hooks/pre-receive`.
# Its outputs are logged to `/tmp/pre-receive.log`.

# script parameters
ruby_git="/var/git/ruby.git"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

echo "### start ($(date)) ###"

echo "==> prohibit merge commits ($(date))"
$ruby_commit_hook/bin/prohibit-merge-commits.rb $* || exit 1

echo "==> check email ($(date))"
$ruby_commit_hook/bin/check-email.rb $* || exit 1

echo "### end ($(date)) ###"; echo
