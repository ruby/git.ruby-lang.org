#!/bin/bash -u
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.git/hooks/post-receive`.
# Its outputs are logged to `/tmp/post-receive.log`.

# script parameters
ruby_git="/var/git/ruby.git"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

# Cancel impact of SSH Agent Forwarding to git push by matzbot
unset SSH_AUTH_SOCK

# Cancel impact from LANG=C set by apache2
export LANG=en_US.UTF-8

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1"
}

log "### start ###"
log "SVN_ACCOUNT_NAME: ${SVN_ACCOUNT_NAME:-}"
log "args: $*"

log "### end ###\n"
