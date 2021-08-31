#!/bin/bash -eu
# This is executed as `sudo -u git /home/git/ruby-commit-hook/bin/update-default-gem.sh`
# when GitHub ruby/xxx's push webhook is delivered to `cgi-bin/webhook.cgi`.
#
# This supports only updating master branch for now.

# Cancel impact from git hook
unset GIT_DIR

# Cancel impact from LANG=C set by apache2
export LANG=en_US.UTF-8

gem_name="$1"
before="$2"
after="$3"
ruby_repo="/var/git/ruby.git"
ruby_workdir="/home/git/update-default-gem-${gem_name}"
log_path="/tmp/update-default-gem-${gem_name}.log"

function log() {
  echo -e "[$$: $(date "+%Y-%m-%d %H:%M:%S %Z")] $1" >> "$log_path"
}

# Initialize working directory only if missing
if [ ! -d "$ruby_workdir" ]; then
  git clone "file://${ruby_repo}" "$ruby_workdir"
  git -C "$ruby_workdir" remote add "$gem_name" "https://github.com/ruby/${gem_name}"
fi

log "### start ###"

git -C "$ruby_workdir" fetch "$gem_name" "$gem_name/master" >> "$log_path" 2>&1
git -C "$ruby_workdir" fetch origin master >> "$log_path" 2>&1
git -C "$ruby_workdir" reset --hard origin/master >> "$log_path" 2>&1
for rev in $(git -C "$ruby_workdir" log --reverse --pretty=%H "${before}..${after}"); do
  if git -C "$ruby_workdir" cherry-pick "$rev" >> "$log_path" 2>&1; then
    suffix="https://github.com/ruby/${gem_name}/commit/${rev:0:10}"
    git -C "$ruby_workdir" filter-branch -f --msg-filter 'grep "" - | sed "1s|^|[ruby/'"$gem_name"'] |" && echo && echo '"$suffix" -- HEAD~1..HEAD >> "$log_path" 2>&1
  else
    break
  fi
done

# Pushing ruby_workdir to cgit to make sure all git hooks are performed on sync-ed commits.
if ! SVN_ACCOUNT_NAME=git git -C "$ruby_workdir" push origin "HEAD:master" >> "$log_path" 2>&1; then
    log "Failed: git push"
fi

log "### end ###\n"
