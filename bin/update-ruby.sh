#!/bin/sh -eu
# This is executed as `sudo -u git /home/git/ruby-commit-hook/bin/update-ruby.sh`
# when GitHub ruby's push webhook is delivered to `cgi-bin/webhook.cgi`.
# Also this is triggered on master branch's update hook failure.
#
# This supports only updating master branch for now.

# TODO: cancel GIT_DIR here

# TODO: care about SVN_ACCOUNT_NAME on push
