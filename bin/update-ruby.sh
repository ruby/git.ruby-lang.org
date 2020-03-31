#!/bin/bash -eu
# This is executed as `sudo -u git /home/git/ruby-commit-hook/bin/update-ruby.sh`
# when GitHub ruby's push webhook is delivered to `cgi-bin/webhook.cgi`.
# Also this is triggered on master branch's update hook failure.
#
# This supports only updating master branch for now.

# Cancel impact from git hook
unset GIT_DIR

# Cancel impact from LANG=C set by apache2
export LANG=en_US.UTF-8

ruby_repo="/var/git/ruby.git"
ruby_branch="$1"
ruby_workdir="/home/git/update-ruby"
log_path="/tmp/update-ruby.log"

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1" >> "$log_path"
}

# Initialize working directory only if missing
if [ ! -d "$ruby_workdir" ]; then
  git clone "file://${ruby_repo}" "$ruby_workdir"
  git -C "$ruby_workdir" remote add github https://github.com/ruby/ruby
fi

log "### start ###"

# Sync: GitHub -> ruby_workdir -> cgit
# By doing this way, we can make sure all git hooks are performed on sync-ed commits.
git -C "$ruby_workdir" pull github "$ruby_branch" >> "$log_path" 2>&1
SVN_ACCOUNT_NAME=git git -C "$ruby_workdir" push origin "$ruby_branch" >> "$log_path" 2>&1

log "### end ###\n"
