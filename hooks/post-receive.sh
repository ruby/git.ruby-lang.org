#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby-commit-hook.git/hooks/post-receive`.
# So we should NOT put anything here until an equivalent thing is dropped from svn side.
#
# Until migration to git is finished, we should develop `hooks/post-receive-pre.sh` and test it
# on `git@git.ruby-lang.org:ruby.pre.git`.
# Make sure this script is executed asynchronously using `&`, since this script is a little slow.

# script parameters
ruby_git="/var/git/ruby.git"
hook_log="/tmp/post-receive.log"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

{ date; echo '### start ###'; uptime; } >> "$hook_log"

# TODO: commit-email
# { date; echo commit-email.rb; uptime; } >> "$hook_log"
# "${ruby_commit_hook}/svn-utils/bin/commit-email.rb" \
#    "$REPOS" "$REV" ruby-cvs@ruby-lang.org \
#    -I "${ruby_commit_hook}/svn-utils/lib" \
#    --name Ruby \
#    --viewvc-uri https://svn.ruby-lang.org/cgi-bin/viewvc.cgi \
#    -r https://svn.ruby-lang.org/repos/ruby \
#    --rss-path /tmp/ruby.rdf \
#    --rss-uri https://svn.ruby-lang.org/rss/ruby.rdf \
#    --error-to cvs-admin@ruby-lang.org

# auto-style (implemented but not enabled yet)

# TODO: update-version

{ date; echo redmine fetch changesets; uptime; } >> "$hook_log"
curl "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~git/config/redmine.key`" &

{ date; echo github sync; uptime; } >> "$hook_log"
git remote update; git push github

{ date; echo notify slack; uptime; } >> "$hook_log"
$ruby_commit_hook/notify-slack.rb $*

{ date; echo '### end ###'; uptime; } >> "$hook_log"
