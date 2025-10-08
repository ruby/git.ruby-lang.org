#!/bin/sh -eux
# This is executed as `sudo -u git /home/git/git.ruby-lang.org/bin/update-git-ruby-lang-org.sh`
# by ruby/git.ruby-lang.org/.github/workflows/deploy.yml.

git -C /home/git/git.ruby-lang.org pull origin master
