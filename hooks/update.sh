#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.git/hooks/update`.
# Its outputs are logged to `/tmp/update.log`.

refname="$1"
oldrev="$2"
newrev="$3"

# Cancel impact of SSH Agent Forwarding to git push by matzbot
unset SSH_AUTH_SOCK

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1"
}

log "### start ###"
log "SVN_ACCOUNT_NAME: ${SVN_ACCOUNT_NAME:-}"
log "args: $*"

log "==> git push github ($newrev:$refname)"
if ! git push github "$newrev:$refname"; then
  if [ "$refname" = "refs/heads/master" ]; then
    nohup /home/git/git.ruby-lang.org/bin/update-ruby.sh master > /dev/null 2>&1 &
  fi
  exit 1
fi

log "### end ###\n"
