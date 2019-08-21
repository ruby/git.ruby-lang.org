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

# normalize branch for mirroring master <-> trunk
if [ "$refname" = "refs/heads/trunk" ]; then
  refname="refs/heads/master"
fi

log "==> git push github ($newrev:$refname)"
if [ "${SVN_ACCOUNT_NAME:-}" = "ko1" -o "${SVN_ACCOUNT_NAME:-}" = "k0kubun" ]; then
  env
  ssh -T git@github.com
fi
if ! git push github "$newrev:$refname"; then
  if [ "$refname" = "refs/heads/master" ]; then
    nohup /home/git/ruby-commit-hook/bin/update-ruby.sh > /dev/null 2>&1 &
  fi
  exit 1
fi

# Mirror master <-> trunk without `push --mirror`, on GitHub side.
# cgit is always mirroed by symbolic ref. TODO: drop trunk (in 2020)
if [ "$refname" = "refs/heads/master" ]; then
  log "==> git push github (mirror: $newrev:refs/heads/trunk)"
  nohup git push github "$newrev:refs/heads/trunk" > /dev/null 2>&1 &
fi

log "### end ###\n"
