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
this_repo="$(cd "$(dirname $0)"; cd ..; pwd)"

# { date; echo commit-email.rb; uptime; } >> "$hook_log"
# TODO 1: send commit log email to ruby-cvs@ruby-lang.org -- "${this_repo}/svn-utils/bin/commit-email.rb" ...

{ date; echo auto-style; uptime; } >> "$hook_log"
"${this_repo}/svn-utils/bin/auto-style.rb" "$ruby_git"

# { date; echo update-version.h.rb; uptime; } >> "$hook_log"
# TODO 2: update revision.h -- "${this_repo}/svn-utils/bin/update-version.h.rb" "$REPOS" "$REV" &

{ date; echo redmine fetch changesets; uptime; } >> "$hook_log"
curl "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~git/config/redmine.key`" &

{ date; echo github sync; uptime; } >> "$hook_log"
git remote update; git push github

{ date; echo notify slack; uptime; } >> "$hook_log"
while read oldrev newrev refname
do
	$ruby_commit_hook/notify-slack.rb $oldrev $newrev
done

{ date; echo '### end ###'; uptime; } >> "$hook_log"
