#!/usr/bin/env ruby

require "open3"

ARGV.each_slice(3) do |oldrev, newrev, refname|
  out, _err, status = Open3.capture3("git", "rev-list", "--parents", "#{oldrev}..#{newrev}")
  if status.success?
    out.lines.each do |s|
      # Allow merge commits in stable branches to preserve history for stable releases
      if s.split.size >= 3 && !File.basename(refname).match?(/\Aruby_\d+_\d+\z/)
        STDERR.puts "A merge commit is prohibited for #{refname}."
        exit 1
      end
    end
  end
end
