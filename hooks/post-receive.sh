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

{ date; echo '### start ###'; uptime; } >> "$hook_log"

{ date; echo redmine fetch changesets; uptime; } >> "$hook_log"
curl "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~git/config/redmine.key`" &

{ date; echo github sync; uptime; } >> "$hook_log"
git remote update; git push github

{ date; echo '### end ###'; uptime; } >> "$hook_log"
