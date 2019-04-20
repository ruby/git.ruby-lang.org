#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.pre.git/hooks/post-receive`.
# The ruby.pre repository is just a sandbox, and any commit isn't pushed to it automatically.
#
# In the future, we'll copy this `hooks/post-receive-pre.sh` to `hooks/post-receive.sh`
# to activate this hook's functionality on Ruby's official git repository.
# Make sure this script is executed asynchronously using `&`, since this script is a little slow.

# script parameters
ruby_git="/var/git/ruby.pre.git"
hook_log="/tmp/post-receive-pre.log"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

{ date; echo '### start ###'; uptime; } >> "$hook_log"
export RUBY_GIT_HOOK=1 # used by auto-style.rb

# TODO: Enable the following code when in production
# { date; echo commit-email.rb; uptime; } >> "$hook_log"
# "${ruby_commit_hook}/svn-utils/bin/commit-email.rb" \
#    "$REPOS" "$REV" ruby-cvs@ruby-lang.org \
#    -I "${ruby_commit_hook}/svn-utils/lib" \
#    --name Ruby \
#    --viewvc-uri https://svn.ruby-lang.org/cgi-bin/viewvc.cgi \
#    -r https://svn.ruby-lang.org/repos/ruby \
#    --rss-path /tmp/ruby.rdf \
#    --rss-uri https://svn.ruby-lang.org/rss/ruby.rdf \
#    --error-to cvs-admin@ruby-lang.org \
#    --vcs git

{ date; echo auto-style; uptime; } >> "$hook_log"
"${ruby_commit_hook}/svn-utils/bin/auto-style.rb" "$ruby_git"

# { date; echo update-version.h.rb; uptime; } >> "$hook_log"
# TODO 2: update revision.h
# "${ruby_commit_hook}/svn-utils/bin/update-version.h.rb" git "$REPOS" "$REV" &

{ date; echo redmine fetch changesets; uptime; } >> "$hook_log"
curl "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~git/config/redmine.key`" &

# TODO: Enable the following code when in production
# { date; echo github sync; uptime; } >> "$hook_log"
# git remote update; git push github

# TODO: Enable the following code when in production
# { date; echo notify slack; uptime; } >> "$hook_log"
# $ruby_commit_hook/notify-slack.rb $*

{ date; echo '### end ###'; uptime; } >> "$hook_log"
