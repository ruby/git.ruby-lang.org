#!/bin/bash -u
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.pre.git/hooks/post-receive`.
# The ruby.pre repository is just a sandbox, and any commit isn't pushed to it automatically.
# Its outputs are logged to `/tmp/post-receive-pre.log`.

# script parameters
ruby_git="/var/git/ruby.pre.git"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1"
}

log "### start ###"
log "args: $*"

# log "==> github sync"
# git remote update; git push github

# log "==> notify slack"
# "${ruby_commit_hook}/bin/notify-slack.rb" $*

# log "==> commit-email.rb"
# "${ruby_commit_hook}/bin/commit-email.rb" \
#    "$ruby_git" ruby-cvs@ruby-lang.org $* \
#    --name Ruby \
#    --viewer-uri "https://git.ruby-lang.org/ruby.git/commit/?id=" \
#    -r https://svn.ruby-lang.org/repos/ruby \
#    --rss-path /tmp/ruby.rdf \
#    --rss-uri https://svn.ruby-lang.org/rss/ruby.rdf \
#    --error-to cvs-admin@ruby-lang.org

log "==> redmine fetch changesets"
curl -s "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~git/config/redmine.key`" &

# Make extra commits from here.
# The above procedure will be executed for the these commits in another post-receive hook.

log "==> auto-style"
SVN_ACCOUNT_NAME=git "${ruby_commit_hook}/bin/auto-style.rb" "$ruby_git" $*

log "==> update-version.h.rb"
SVN_ACCOUNT_NAME=git "${ruby_commit_hook}/bin/update-version.h.rb" git "$ruby_git" $*

log "### end ###\n"
