#!/bin/bash -eux
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.pre.git/hooks/post-receive`.
# The ruby.pre repository is just a sandbox, and any commit isn't pushed to it automatically.
#
# In the future, we'll copy this `hooks/post-receive-pre.sh` to `hooks/post-receive.sh`
# to activate this hook's functionality on Ruby's official git repository.
