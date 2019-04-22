#!/usr/bin/env ruby

require "open3"

ARGV.each_slice(3) do |oldrev, newrev, refname|
  out, = Open3.capture2("git", "rev-list", "--parents", oldrev + ".." + newrev)
  out.lines.each do |s|
    if s.split.size >= 3
      puts "A merge commit is prohibited."
      exit 1
    end
  end
end
