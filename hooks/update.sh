#!/bin/bash -eu
set -o pipefail
# This script is executed by `git@git.ruby-lang.org:ruby.git/hooks/update`.
# Its outputs are logged to `/tmp/update.log`.

refname="$1"
oldrev="$2"
newrev="$3"

git push github "$newrev:$refname"
