#!/bin/bash -eu
# This is executed as `sudo -u git /home/git/git.ruby-lang.org/bin/update-default-gem.sh`
# when GitHub ruby/xxx's push webhook is delivered to `cgi-bin/webhook.cgi`.
#
# This supports only updating master branch for now.

# Cancel impact from git hook
unset GIT_DIR

# Cancel impact from LANG=C set by apache2
export LANG=en_US.UTF-8

gem_user="$1"
gem_name="$2"
before="$3"
after="$4"
this_repo="/home/git/git.ruby-lang.org"
ruby_repo="/var/git/ruby.git"
ruby_workdir="/data/git.ruby-lang.org/update-default-gem-${gem_name}"
log_path="/tmp/update-default-gem-${gem_name}.log"

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1" >> "$log_path"
}

# Run a given command. If it fails, notify Slack and exits abnormally.
function run() {
  echo "+ $@" >> "$log_path"
  if ! "$@"; then
    "${this_repo}/bin/notify-slack-failed-gem-update.rb" "$log_path" >> "$log_path" 2>&1
    log "Failed: $@"
    exit 1
  fi
}

# Initialize working directory only if missing
if [ ! -d "$ruby_workdir" ]; then
  git clone "file://${ruby_repo}" "$ruby_workdir"
fi

log "### start ###"

run git -C "$ruby_workdir" fetch origin master >> "$log_path" 2>&1
run git -C "$ruby_workdir" reset --hard origin/master >> "$log_path" 2>&1

run ruby -C "$ruby_workdir" tool/sync_default_gems.rb "$gem_name" "$before..$after" >> "$log_path" 2>&1

# Pushing ruby_workdir to cgit to make sure all git hooks are performed on sync-ed commits.
SVN_ACCOUNT_NAME=git run git -C "$ruby_workdir" push origin "HEAD:master" >> "$log_path" 2>&1

log "### end ###\n"
