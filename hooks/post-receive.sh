#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby-commit-hook.git/hooks/post-receive`.
# So we should NOT put anything here until an equivalent thing is dropped from svn side.
#
# Until migration to git is finished, we should develop `hooks/post-receive-pre.sh` and test it
# on `git@git.ruby-lang.org:ruby.pre.git`.
# Make sure this script is executed asynchronously using `&`, since this script is a little slow.
