#!/usr/bin/env ruby
#
#$:.unshift File.join(File.dirname(__FILE__), "lib")
home = "/export/home/svn"
$:.unshift home + "/scripts/svn-util/lib"
require "fileutils"
require "svn/info"

repos, revision = ARGV

info = Svn::Info.new repos, revision
branches = info.sha256.map{|x,| x[/((?:branches\/)?.+?)\//, 1]}.uniq
branches.each do |b|
  if info.diffs.map{|f,|f}.grep(/#{b}\/version\.h/).empty?
    Dir.chdir home
    FileUtils.rm_rf "work/version"
    FileUtils.mkdir_p "work/version/.svn/tmp"
    File.open("work/version/.svn/entries", "w") do |fh|
      fh.print "8\n\ndir\n1\nfile:///#{repos}/#{b}\nfile:///#{repos}\n\f\n"
    end
    Dir.chdir "work/version"
    system "svn cleanup; cp -rp .svn/tmp/* .svn; svn up version.h"
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
          fnew.print line
        end
      end
    end
    system "svn commit -m #{now.strftime '%Y-%m-%d'} version.h"
  end
end
