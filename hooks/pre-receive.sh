#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.git/hooks/pre-receive`.
# Its outputs are logged to `/tmp/pre-receive.log`.

# script parameters
ruby_git="/var/git/ruby.git"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1"
}

log "### start ###"
log "args: $*"

log "==> prohibit merge commits"
"${ruby_commit_hook}/bin/prohibit-merge-commits.rb" $* || exit 1

log "==> check email and refname"
"${ruby_commit_hook}/bin/check-email-and-refname.rb" $* || exit 1

log "==> github sync"
time "${ruby_commit_hook}/bin/git-push-github.rb" "$ruby_git" $* || exit 1

log "### end ###\n"
