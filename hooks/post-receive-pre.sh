#!/bin/bash -eux
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.pre.git/hooks/post-receive`.
# The ruby.pre repository is just a sandbox, and any commit isn't pushed to it automatically.
#
# In the future, we'll copy this `hooks/post-receive-pre.sh` to `hooks/post-receive.sh`
# to activate this hook's functionality on Ruby's official git repository.

this_repo="$(cd "$(dirname $0)"; cd ..; pwd)"
hook_log="/tmp/post-receive-pre.log"

{ date; echo '### start ###'; uptime; } >> "$hook_log"
export RUBY_GIT_HOOK=1 # used by auto-style.rb

# { date; echo $REPOS; echo $REV; echo svnadmin; uptime; } >> "$hook_log"
# XXX: do we need to dump git repository like `svnadmin dump`?

# { date; echo commit-email.rb; uptime; } >> "$hook_log"
# TODO 1: send commit log email to ruby-cvs@ruby-lang.org -- "${this_repo}/svn-utils/bin/commit-email.rb" ...

# { date; echo auto-style; uptime; } >> "$hook_log"
# TODO 2: "${this_repo}/svn-utils/bin/auto-style.rb" "/path/to/ruby.pre"

# { date; echo update-version.h.rb; uptime; } >> "$hook_log"
# TODO 3: update revision.h -- "${this_repo}/svn-utils/bin/update-version.h.rb" "$REPOS" "$REV" &

# { date; echo redmine fetch changesets; uptime; } >> "$hook_log"
# TODO 4: curl "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~svn/config/redmine.key`" &

# { date; echo github sync; uptime; } >> "$hook_log"
# TODO 5: push branch or tag to GitHub, delete branch or tag on GitHub

{ date; echo '### end ###'; uptime; } >> "$hook_log"
