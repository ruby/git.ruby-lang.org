#!/usr/bin/env ruby
#
#$:.unshift File.join(File.dirname(__FILE__), "lib")
home = File.expand_path "~"
$:.unshift home + "/scripts/svn-util/lib"
require "fileutils"
require "tmpdir"
require "svn/info"

repos, revision = ARGV

info = Svn::Info.new repos, revision
branches = info.sha256.map{|x,| x[/((?:branches\/)?.+?)\//, 1]}.uniq
branches.each do |branch|
  Dir.mktmpdir do |work|
    Dir.chdir work
    system "svn co --depth empty file:///#{repos}/#{branch} v; svn up v/version.h"
    Dir.chdir "v"
    formats = {
      'DATE' => [/"\d{4}-\d\d-\d\d"/, '"%Y-%m-%d"'],
      'TIME' => [/".+"/, '"%H:%M:%S"'],
      'CODE' => [/\d+/, '%Y%m%d'],
      'YEAR' => [/\d+/, '%Y'],
      'MONTH' => [/\d+/, '%m'],
      'DAY' => [/\d+/, '%d']
    }

    now = Time.now

    File.rename "version.h", "version.h~"
    open("version.h~") do |fold|
      open("version.h", "w") do |fnew|
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
    system "svn commit -m '#{now.strftime %(* %Y-%m-%d)}' version.h"
    Dir.chdir "/"
  end
end
