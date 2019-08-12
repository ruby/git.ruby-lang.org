#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.git/hooks/update`.
# Its outputs are logged to `/tmp/update.log`.

refname="$1"
oldrev="$2"
newrev="$3"

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1"
}

log "### start ###"
log "args: $*"

log "==> git push github"
if ! git push github "$newrev:$refname"; then
  if [ "$refname" = "refs/heads/master" ]; then
    nohup /home/git/ruby-commit-hook/bin/update-ruby.sh > /dev/null 2>&1 &
  fi
  exit 1
fi

log "### end ###\n"
