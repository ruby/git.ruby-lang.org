#!/bin/sh

{ date; echo '### start ###'; uptime; } >> /tmp/post-commit.log

PATH=/opt/csw/bin:/usr/sfw/bin:/usr/bin:/bin
export PATH

REPOS="$1"
REV="$2"

{ date; echo svnadmin; uptime; } >> /tmp/post-commit.log

svnadmin dump -q -r "$REV" --incremental "$REPOS" | bzip2 -c > /var/svn/dump/ruby/$REV.bz2

{ date; echo commit-email.rb; uptime; } >> /tmp/post-commit.log

/export/home/svn/scripts/svn-utils/bin/commit-email.rb \
   "$REPOS" "$REV" ruby-cvs@ruby-lang.org \
   -I /export/home/svn/scripts/svn-utils/lib \
   --name Ruby \
   --viewvc-uri http://svn.ruby-lang.org/cgi-bin/viewvc.cgi \
   --error-to cvs-admin@ruby-lang.org

{ date; echo update-version.h.rb; uptime; } >> /tmp/post-commit.log

/export/home/svn/scripts/svn-utils/bin/update-version.h.rb "$REPOS" "$REV" &

#/export/home/svn/scripts/svn-utils/bin/commit-email-test.rb \
#   "$REPOS" "$REV" eban@ruby-lang.org \
#   -I /export/home/svn/scripts/svn-utils/lib \
#   --name Ruby \
#   --viewvc-uri http://svn.ruby-lang.org/cgi-bin/viewvc.cgi \
#   --error-to eban@ruby-lang.org

#   --from admin@ruby-lang.org
#   -r http://svn.ruby-lang.org/repos/ruby \
#   --rss-path ~/ruby.rdf \
#   --rss-uri http://svn.ruby-lang.org/rss/ruby.rdf \

{ date; echo ciabot_svn.py; uptime; } >> /tmp/post-commit.log

/export/home/svn/scripts/cia/ciabot_svn.py "$REPOS" "$REV" ruby &

{ date; echo '### end ###'; uptime; } >> /tmp/post-commit.log
