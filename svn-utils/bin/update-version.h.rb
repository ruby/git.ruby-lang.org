#!/usr/bin/env ruby

require "fileutils"
require "tmpdir"
require "svn/info"

repos, revision = ARGV

sha256 = Svn::Info.new(repos, revision).sha256
branches = sha256.map{|x,| x[/((?:branches\/)?.+?)\//, 1]}.uniq
branches.each do |branch|
  Dir.mktmpdir do |work|
    v = File.join(work, "v")
    version_h = "#{v}/version.h"
    version_h_orig = version_h + "~"

    system "pwd;echo 1;svn co --depth empty file:///#{repos}/#{branch} #{v}; svn up #{version_h}"
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
    system "svn commit -m '#{now.strftime %(* %Y-%m-%d)}' #{version_h}"
  end
end
