#!/bin/sh

{ date; echo '### start ###'; uptime; } >> /tmp/post-commit.log

PATH=/opt/csw/bin:/usr/sfw/bin:/usr/bin:/bin
export PATH
HOME=/home/svn
export HOME

REPOS="$1"
REV="$2"

{ date; echo $REPOS; echo $REV; echo svnadmin; uptime; } >> /tmp/post-commit.log

svnadmin dump -q -r "$REV" --incremental "$REPOS" | bzip2 -c > /var/svn/dump/ruby/$REV.bz2

{ date; echo commit-email.rb; uptime; } >> /tmp/post-commit.log

~svn/scripts/svn-utils/bin/commit-email.rb \
   "$REPOS" "$REV" ruby-cvs@ruby-lang.org \
   -I ~svn/scripts/svn-utils/lib \
   --name Ruby \
   --viewvc-uri http://svn.ruby-lang.org/cgi-bin/viewvc.cgi \
   -r http://svn.ruby-lang.org/repos/ruby \
   --rss-path /tmp/ruby.rdf \
   --rss-uri http://svn.ruby-lang.org/rss/ruby.rdf \
   --error-to cvs-admin@ruby-lang.org

{ date; echo update-version.h.rb; uptime; } >> /tmp/post-commit.log

~svn/scripts/svn-utils/bin/update-version.h.rb "$REPOS" "$REV" &

#~svn/scripts/svn-utils/bin/commit-email-test.rb \
#   "$REPOS" "$REV" eban@ruby-lang.org \
#   -I ~svn/scripts/svn-utils/lib \
#   --name Ruby \
#   --viewvc-uri http://svn.ruby-lang.org/cgi-bin/viewvc.cgi \
#   --error-to eban@ruby-lang.org

#   --from admin@ruby-lang.org
#   -r http://svn.ruby-lang.org/repos/ruby \
#   --rss-path ~/ruby.rdf \
#   --rss-uri http://svn.ruby-lang.org/rss/ruby.rdf \

{ date; echo redmine fetch changesets; uptime; } >> /tmp/post-commit.log

curl "https://bugs.ruby-lang.org/sys/fetch_changesets?key=`cat ~svn/config/redmine.key`" &

{ date; echo auto-style; uptime; } >> /tmp/post-commit.log

~svn/scripts/svn-utils/bin/auto-style.rb ~svn/ruby/trunk &

{ date; echo github sync; uptime; } >> /tmp/post-commit.log

cd /var/git-svn/ruby
for branch in trunk ruby_2_2 ruby_2_1 ruby_2_0_0 ruby_1_9_3; do
  sudo -u git git checkout $branch
  sudo -u git git svn rebase
done
sudo -u git git push

{ date; echo '### end ###'; uptime; } >> /tmp/post-commit.log
