#!/usr/bin/env ruby

require "fileutils"
require "tmpdir"

vcs, repo_path, *rest = ARGV
case vcs
when "svn"
  require_relative "../lib/svn/info"
  branches = Svn::Info.new(repo_path, rest.first).branches
when "git"
  require "open3"
  branches = rest.each_slice(3).map do |_oldrev, _newrev, refname|
    out, _ = Open3.capture2("git", "rev-parse", "--symbolic", "--abbrev-ref", refname)
    out.strip
  end.uniq
  p branches
else
  raise "unknown vcs: #{vcs.inspect}"
end

branches.each do |branch|
  Dir.mktmpdir do |work|
    v = File.join(work, "v")
    version_h = "#{v}/version.h"
    version_h_orig = version_h + "~"

    if vcs == "svn"
      system "pwd;echo 1;svn co --depth empty file:///#{repo_path}/#{branch} #{v}; svn up #{version_h}"
    else # git
      system "git clone --depth=1 --branch=#{branch} file:///#{repo_path} #{v}"
    end
    formats = {
      'DATE' => [/"\d{4}-\d\d-\d\d"/, '"%Y-%m-%d"'],
      'TIME' => [/".+"/, '"%H:%M:%S"'],
      'CODE' => [/\d+/, '%Y%m%d'],
      'YEAR' => [/\d+/, '%Y'],
      'MONTH' => [/\d+/, '%m'],
      'DAY' => [/\d+/, '%d']
    }

    now = Time.now

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
    if vcs == "svn"
      system "svn commit -m '#{now.strftime %(* %Y-%m-%d)}' #{version_h}"
    else
      Dir.chdir(v) do
        system "git add #{version_h} && git commit -m '#{now.strftime %(* %Y-%m-%d)}' && git push origin #{branch}"
      end
    end
  end
end
