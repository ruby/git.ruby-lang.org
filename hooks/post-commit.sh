#!/bin/sh

PATH=/opt/csw/bin:/usr/sfw/bin:/usr/bin
export PATH

REPOS="$1"
REV="$2"

svnadmin dump -q -r "$REV" --incremental "$REPOS" | bzip2 -c > /var/svn/dump/ruby/$REV.bz2

/export/home/svn/scripts/svn-utils/bin/commit-email.rb \
   "$REPOS" "$REV" ruby-cvs@ruby-lang.org \
   -I /export/home/svn/scripts/svn-utils/lib \
   --name Ruby \
   --viewvc-uri http://svn.ruby-lang.org/cgi-bin/viewvc.cgi \
   --error-to cvs-admin@ruby-lang.org

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

#/export/home/svn/scripts/cia/ciabot_svn.py "$REPOS" "$REV" ruby &
