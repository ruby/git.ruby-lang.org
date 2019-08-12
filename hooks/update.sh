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
git push github "$newrev:$refname"

log "### end ###\n"
