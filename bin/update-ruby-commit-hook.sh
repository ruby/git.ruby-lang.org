#!/bin/sh -eu
# This is executed as `sudo -u git /home/git/ruby-commit-hook/bin/update-ruby-commit-hook.sh`
# when GitHub ruby-commit-hook's push webhook is delivered to `cgi-bin/webhook.cgi`.

# TODO: maybe better to take flock because concurrent `git pull` can be dangerous.

git -C /home/git/ruby-commit-hook pull origin master
