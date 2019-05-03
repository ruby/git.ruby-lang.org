#!/usr/bin/env ruby

require "fileutils"
require "tmpdir"

vcs, repo_path, *rest = ARGV
case vcs
when "svn"
  class SvnInfo
    def initialize(repo_path, rev)
      @repo_path = repo_path
      @revision = Integer(rev)
      get_changed
    end

    def branches
      [*@added_files, *@updated_files].map { |x| x[/((?:branches\/)?.+?)\//, 1] }.uniq
    end

    private

    def get_changed
      @added_files = []
      @updated_files = []
      svnlook("changed").each_line do |line|
        if /^(.).  (.*)$/ =~ line
          modified_type = $1
          path = $2
          case modified_type
          when "A"
            add_path(path, @added_files)
          when "D"
            # noop
          else
            add_path(path, @updated_files)
          end
        else
          raise "unknown format: #{line}"
        end
      end
    end

    def add_path(path, files)
      unless directory_path?(path)
        files << path
      end
    end

    def svnlook(command, *others)
      `svnlook #{command} #{@repo_path} -r #{@revision} #{others.join(' ')}`.force_encoding("ASCII-8BIT")
    end

    def directory_path?(path)
      path[-1] == ?/
    end
  end
  branches = SvnInfo.new(repo_path, rest.first).branches
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
        unless system("git diff --quiet --exit-code #{version_h}")
          system "git add #{version_h} && git commit -m '#{now.strftime %(* %Y-%m-%d)}' && git push origin #{branch}"
        end
      end
    end
  end
end
