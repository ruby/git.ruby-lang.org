#!/bin/bash -ux
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.pre.git/hooks/post-receive`.
# The ruby.pre repository is just a sandbox, and any commit isn't pushed to it automatically.
# Its outputs are logged to `/tmp/post-receive-pre.log`.

# script parameters
ruby_git="/var/git/ruby.pre.git"
ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

echo "### start ($(date)) ###"

# echo "==> github sync ($(date))"
# git remote update; git push github

# echo "==> notify slack ($(date))"
# "${ruby_commit_hook}/bin/notify-slack.rb" $*

# echo "==> commit-email.rb ($(date))"
# "${ruby_commit_hook}/bin/commit-email.rb" \
#    "$ruby_git" ruby-cvs@ruby-lang.org $* \
#    -I "${ruby_commit_hook}/lib" \
#    --name Ruby \
#    --viewer-uri "https://git.ruby-lang.org/ruby.git/commit/?id=" \
#    -r https://svn.ruby-lang.org/repos/ruby \
#    --rss-path /tmp/ruby.rdf \
#    --rss-uri https://svn.ruby-lang.org/rss/ruby.rdf \
#    --error-to cvs-admin@ruby-lang.org \
#    --vcs git

echo "==> redmine fetch changesets ($(date))"
curl "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~git/config/redmine.key`" &

# Make extra commits from here.
# The above procedure will be executed for the these commits in another post-receive hook.

echo "==> auto-style ($(date))"
SVN_ACCOUNT_NAME=git "${ruby_commit_hook}/bin/auto-style.rb" "$ruby_git" $*

echo "==> update-version.h.rb ($(date))"
SVN_ACCOUNT_NAME=git "${ruby_commit_hook}/bin/update-version.h.rb" git "$ruby_git" $*

echo "### end ($(date)) ###"; echo
