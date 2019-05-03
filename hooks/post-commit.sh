#!/bin/sh
# This hook is used by Ruby's SVN repository on svn.ruby-lang.org.
# Its outputs are logged to `/tmp/post-commit.log`.

{ date; echo '### start ###'; uptime; }

PATH=/usr/bin:/bin
export PATH
HOME=/home/svn
export HOME

# REPOS=/var/svn/repos/ruby
REPOS="$1"
REV="$2"

ruby_commit_hook="$(cd "$(dirname $0)"; cd ..; pwd)"

{ date; echo $REPOS; echo $REV; echo svnadmin; uptime; }
svnadmin dump -q -r "$REV" --incremental "$REPOS" | bzip2 -c > /var/svn/dump/ruby/$REV.bz2

{ date; echo update-version.h.rb; uptime; }
"${ruby_commit_hook}/bin/update-version.h.rb" svn "$REPOS" "$REV" &

{ date; echo cgit sync; uptime; }
cd /var/git-svn/ruby
flock -w 100 "$0" sudo -u git git svn fetch --all

# Push branch or tag
for ref in `svnlook changed -r $REV $REPOS | grep '^[AU ]' |                                            sed 's!^..  \(\(trunk\)/.*\|\(tags\|branches\)/\([^/]*\)/.*\)!\2\4!' | sort -u`; do
  case $ref in
  # trunk) sudo -u git git push cgit svn/trunk:trunk ;;
  ruby_*) sudo -u git git push cgit svn/$ref:refs/heads/$ref ;;
  v*) sudo -u git git tag -f $ref svn/tags/$ref && sudo -u git git push cgit $ref;;
  esac
done

# Delete tags or branches
for ref in `svnlook changed -r $REV $REPOS |                                                            grep '^D   \(tags\|branches\)/[^/]*/$' | sed 's!^D   \(tags\|branches\)/\([^/]*\)/$!\2!'`; do
  sudo -u git git push cgit :$ref
done

{ date; echo '### end ###'; uptime; }
