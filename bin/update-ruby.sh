#!/bin/bash -eu
# This is executed as `sudo -u git /home/git/git.ruby-lang.org/bin/update-ruby.sh`
# by ruby/ruby/.github/workflows/post_push.yml.
# This is also triggered on master branch's update hook failure.

# Cancel impact from git hook
unset GIT_DIR

# Cancel impact from LANG=C set by apache2
export LANG=en_US.UTF-8

ruby_repo="/var/git/ruby.git"
ruby_branch="$(basename "$1")"
ruby_workdir="/data/git.ruby-lang.org/update-ruby"

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1"
}

# Initialize working directory only if missing
if [ ! -d "$ruby_workdir" ]; then
  git clone "file://${ruby_repo}" "$ruby_workdir"
  git -C "$ruby_workdir" remote add github https://github.com/ruby/ruby
fi

log "### start ###"

# Sync: GitHub -> ruby_workdir -> cgit
# By doing this way, we can make sure all git hooks are performed on sync-ed commits.
git -C "$ruby_workdir" fetch github "$ruby_branch"
SVN_ACCOUNT_NAME=git git -C "$ruby_workdir" push origin "github/${ruby_branch}:${ruby_branch}"

log "### end ###\n"
