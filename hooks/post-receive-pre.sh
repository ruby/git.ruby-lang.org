#!/bin/bash -eux
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.pre.git/hooks/post-receive`.
# The ruby.pre repository is just a sandbox, and any commit isn't pushed to it automatically.

# script parameters
ruby_git="/var/git/ruby.pre.git"
hook_log="/tmp/post-receive-pre.log"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

{ date; echo; echo '### start ###'; uptime; } >> "$hook_log"

# { date; echo '==> github sync'; uptime; } >> "$hook_log"
# git remote update; git push github

# { date; echo '==> notify slack'; uptime; } >> "$hook_log"
# "${ruby_commit_hook}/bin/notify-slack.rb" $*

# { date; echo '==> commit-email.rb'; uptime; } >> "$hook_log"
# "${ruby_commit_hook}/bin/commit-email.rb" \
#    "$ruby_git" ruby-cvs@ruby-lang.org $* \
#    -I "${ruby_commit_hook}/lib" \
#    --name Ruby \
#    --viewer-uri "https://git.ruby-lang.org/ruby.git/commit/?id=" \
#    -r https://svn.ruby-lang.org/repos/ruby \
#    --rss-path /tmp/ruby.rdf \
#    --rss-uri https://svn.ruby-lang.org/rss/ruby.rdf \
#    --error-to cvs-admin@ruby-lang.org \
#    --vcs git \
#    > /tmp/post-receive-pre-commit-email.log 2>&1

{ date; echo '==> redmine fetch changesets'; uptime; } >> "$hook_log"
curl "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~git/config/redmine.key`" &

# Make extra commits from here.
# The above procedure will be executed for the these commits in another post-receive hook.

{ date; echo '==> auto-style'; uptime; } >> "$hook_log"
SVN_ACCOUNT_NAME=git "${ruby_commit_hook}/bin/auto-style.rb" "$ruby_git" $* \
   >> "$hook_log" 2>&1

{ date; echo '==> update-version.h.rb'; uptime; } >> "$hook_log"
SVN_ACCOUNT_NAME=git "${ruby_commit_hook}/bin/update-version.h.rb" git "$ruby_git" $* \
   >> "$hook_log" 2>&1

{ date; echo '### end ###'; uptime; } >> "$hook_log"
