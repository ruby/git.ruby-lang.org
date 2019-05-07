#!/usr/bin/env ruby

require "open3"

ARGV.each_slice(3) do |oldrev, newrev, refname|
  out, _err, status = Open3.capture3("git", "rev-list", "--parents", "#{oldrev}..#{newrev}")
  if status.success?
    out.lines.each do |s|
      if s.split.size >= 3
        STDERR.puts "A merge commit is prohibited."
        exit 1
      end
    end
  end
end
