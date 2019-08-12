#!/usr/bin/env ruby
# This is a helper to sync some set of commits (not all, like --mirror)
# from cgit to GitHub.

# system git is 2.1.4, which does not support `git push --atomic`.
# `/var/git/local/bin/git` is 2.11.0, which supports it and is the
# git version in debian stretch.
GIT = '/var/git/local/bin/git'

git_dir, *rest = ARGV
exit 0 if rest.empty?

args = rest.each_slice(3).map do |_oldrev, newrev, refname|
  "#{newrev}:#{refname}"
end

exec({ 'GIT_DIR' => git_dir }, GIT, 'push', '--atomic', 'github', *args)
