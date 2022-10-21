#!/usr/bin/env ruby

require "fileutils"
require "tmpdir"

vcs, repo_path, *rest = ARGV
case vcs
when "git"
  branches = rest.each_slice(3).map do |_oldrev, _newrev, refname|
    IO.popen(["git", "rev-parse", "--symbolic", "--abbrev-ref", refname], &:read).strip
  end.uniq
else
  raise "unknown vcs: #{vcs.inspect}"
end

branches.each do |branch|
  Dir.mktmpdir do |work|
    v = File.join(work, "v")
    version_h = "#{v}/version.h"
    version_h_orig = version_h + "~"

    system "git clone --depth=1 --branch=#{branch} file:///#{repo_path} #{v}"
    formats = {
      'DATE' => [/"\d{4}-\d\d-\d\d"/, '"%Y-%m-%d"'],
      'TIME' => [/".+"/, '"%H:%M:%S"'],
      'CODE' => [/\d+/, '%Y%m%d'],
      'YEAR' => [/\d+/, '%Y'],
      'MONTH' => [/\d+/, '%m'],
      'DAY' => [/\d+/, '%d']
    }

    now = Time.now

    unless File.exist?(version_h) # refs/notes/commits does not have version.h
      puts "skipped '#{branch}' because '#{version_h}' is missing."
      next
    end

    File.rename version_h, version_h_orig
    open(version_h_orig) do |fold|
      open(version_h, "w") do |fnew|
        while line = fold.gets
          if /RUBY_RELEASE_(#{formats.keys.join('|')})/o =~ line
            format = formats[$1]
            line.sub!(format[0]) do
              now.strftime(format[1]).sub(/^0/, '')
            end
          end
          fnew.puts line.rstrip
        end
      end
    end
    Dir.chdir(v) do
      unless system("git diff --quiet --exit-code #{version_h}")
        system "git add #{version_h} && git commit -m '#{now.strftime %(* %Y-%m-%d)} [ci skip]' && git push origin #{branch}"
      end
    end
  end
end
