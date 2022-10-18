#!/bin/sh -eu
# This is executed as `sudo -u git /home/git/git.ruby-lang.org/bin/update-git-ruby-lang-org.sh`
# when GitHub ruby/git.ruby-lang.org's push webhook is delivered to `cgi-bin/webhook.cgi`.
#
# This supports only updating master branch for now.

git -C /home/git/git.ruby-lang.org pull origin master
