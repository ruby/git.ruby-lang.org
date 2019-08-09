#!/usr/bin/env ruby
# See https://devblog.nestoria.com/post/98892582763/maintaining-a-consistent-linear-history-for-git
# for the motivation of this script and what this script is doing.

CHECKED_REFNAMES = [
  'refs/heads/master',
  'refs/heads/trunk',
]

ARGV.each_slice(3) do |oldrev, newrev, refname|
  next unless CHECKED_REFNAMES.include?(refname) # avoid checking branches pushed from git-svn just in case

  out, _err, status = Open3.capture3("git", "rev-list", "--first-parent", "#{oldrev}^..#{newrev}")
  next unless status.success? # skip if oldrev is the first commit, arguments are invalid, or git is broken
  next if out.empty? # skip if it's an empty push

  ancestor = out.lines.last.chomp
  if ancestor != oldrev
    STDERR.puts "The revision '#{newrev}' pushed to '#{refname}' does not have '#{oldrev}' as a first-parent ancestor, which was '#{ancestor}'."
    STDERR.puts "Please make sure your '#{refname}' is rebased from '#{oldrev}', not '#{ancestor}'. Sometimes it's caused by `git pull` without `--rebase`."
    exit 1
  end
end
