#!/usr/bin/env ruby
#
# Usage:
#   auto-style.rb [directory] # svn mode
#   RUBY_GIT_HOOK=0 auto-style.rb [directory] # svn mode
#   RUBY_GIT_HOOK=1 auto-style.rb [directory] # git mode
#

require 'shellwords'
ENV["LC_ALL"] = "C"

class SVN
  attr_reader :workdir

  def initialize(repo_path)
    @workdir = repo_path
  end

  # ["foo/bar.c", "baz.h", ...]
  def updated_paths
    log = svnread("update", "--accept=postpone")
    log[1...-1].grep(/^[AMU]/) {|l| l.sub(/^[AMU] +/, '') }
  end

  # [0, 1, 4, ...]
  def updated_lines(file)
    return [] if last_rev.nil?

    lines = []
    blames = svnread('blame', file)
    blames.each_with_index do |blame, lineno|
      if blame.match(/\A\s*#{last_rev}\s/)
        lines << lineno
      end
    end
    lines
  end

  def commit(log, *files)
    exec("ci", "-m", log, *files)
  end

  def commit_properties(*files)
    propset("svn:eol-style", "LF", *files)
    files.grep(/\/extconf\.rb$/) do
      dir = $`
      prop = propget("svn:ignore", dir)
      if prop.size < (prop |= %w[Makefile extconf.h mkmf.log]).size
        propset("svn:ignore", dir) {|f| f.puts *prop}
      end
    end
    commit("* properties.", *files)
  end

  def ci_skip?
    last_rev unless defined?(@ci_skip)
    @ci_skip
  end

  private

  def last_rev
    return @last_rev if defined?(@last_rev)
    log = svnread('log', '-r', 'HEAD')
    @ci_skip = (true if /\[ci skip\]/i =~ log[3])
    @last_rev = log[1].match(/\Ar(?<rev>\d+) /)[:rev]
  end

  def exec(*args)
    system("svn", *args)
  end

  def svnread(*args)
    IO.popen(["svn", *args], &:readlines).each(&:chomp!)
  end

  def svnwrite(*args, &block)
    IO.popen(["svn", *args], "w", &block)
  end

  def propget(prop, *args)
    svnread("propget", prop, *args)
  end

  def propset(prop, *args, &block)
    if block
      svnwrite(*%w"propset --file -", prop, *args, &block)
    else
      exec("propset", prop, *args)
    end
  end

  module Debugging
    def commit(*args)
      p args
    end
  end
end

class Git
  attr_reader :workdir

  def initialize(git_dir)
    @workdir = File.expand_path(File.join('../../repos', File.basename(git_dir)), __dir__)

    # Should be done in another method once SVN is deprecated. Now it has only the same methods.
    if Dir.exist?(@workdir)
      Dir.chdir(@workdir) do
        git('clean', '-fdx')
        git('pull')
      end
    else
      git('clone', git_dir, @workdir)
    end
  end

  # ["foo/bar.c", "baz.h", ...]
  def updated_paths
    with_clean_env do
      IO.popen(['git', 'diff', '--name-only', 'HEAD^', 'HEAD'], &:readlines).each(&:chomp!)
    end
  end

  # [0, 1, 4, ...]
  def updated_lines(file)
    return [] if last_rev.nil?

    lines = []
    with_clean_env { IO.popen(['git', 'blame', file], &:readlines) }.each_with_index do |line, index|
      # git 2.1.4 on git@git.ruby-lang.org shows only 8 chars on blame.
      if line[0..7] == last_rev[0..7]
        lines << index
      end
    end
    lines
  end

  def commit(log, *files)
    git('add', *files)
    git('commit', '-m', log)
    git('push', 'origin', current_branch)
  end

  def commit_properties(*files)
    # no-op in git
  end

  def ci_skip?
    unless defined?(@ci_skip)
      @ci_skip = (true if /\[ci skip\]/i =~ with_clean_env {IO.popen(['git', 'log', '-n1' 'HEAD']) {|f| f.gets(""); f.gets}})
    end
    @ci_skip
  end

  private

  def last_rev
    @last_rev ||= with_clean_env { IO.popen(['git', 'rev-parse', 'HEAD'], &:readlines) }.first.chomp!
  end

  def current_branch
    @current_branch ||= with_clean_env { IO.popen(['git', 'rev-parse', '--abbrev-ref', 'HEAD'], &:readlines) }.first.chomp!
  end

  def git(*args)
    cmd = ['git', *args].shelljoin
    unless with_clean_env { system(cmd) }
      abort "Failed to run: #{cmd}"
    end
  end

  def with_clean_env
    git_dir = ENV.delete('GIT_DIR') # this overcomes '-C' or pwd
    yield
  ensure
    ENV['GIT_DIR'] = git_dir if git_dir
  end
end

options = {}
if ARGV[0] == "--debug"
  ARGV.shift
  options[:debug] = true
end
unless ARGV.empty?
  options[:repo_path] = ARGV.shift
end

if ENV['RUBY_GIT_HOOK'] == '1'
  vcs = Git.new(options.fetch(:repo_path))
else
  vcs = SVN.new(options[:repo_path])
  if options[:debug]
    vcs.extend(SVN::Debugging)
  end
end

if vcs.workdir
  Dir.chdir(vcs.workdir)
end

EXPANDTAB_IGNORED_FILES = [
  %r{\Accan/},
  %r{\Aext/json/},
  %r{\Aext/psych/},
  %r{\Aenc/},
  %r{\Amissing/},
  %r{\Ainclude/ruby/onigmo\.h\z},
  %r{\Astrftime\.c\z},
  %r{\Avsnprintf\.c\z},
  %r{\Areg.+\.(c|h)\z},
]

paths = vcs.updated_paths
paths.select! {|l|
  /^\d/ !~ l and /\.bat\z/ !~ l and
  (/\A(?:config|[Mm]akefile|GNUmakefile|README)/ =~ File.basename(l) or
   /\A\z|\.(?:[chsy]|\d+|e?rb|tmpl|bas[eh]|z?sh|in|ma?k|def|src|trans|rdoc|ja|en|el|sed|awk|p[ly]|scm|mspec|html|)\z/ =~ File.extname(l))
}
files = paths.select {|n| File.file?(n)}
if files.empty?
  exit 0
end
translit = trailing = eofnewline = expandtab = false

files.grep(/\/ChangeLog\z/) do |changelog|
  if IO.foreach(changelog, "rb").any? {|line| !line.ascii_only?}
    tmp = changelog+".ascii"
    if system("iconv", "-f", "utf-8", "-t", "us-ascii//translit", changelog, out: tmp) and
        (File.size(tmp) - File.size(changelog)).abs < 10
      File.rename(tmp, changelog)
      translit = true
    else
      File.unlink(tmp) rescue nil
    end
  end
end

edited_files = files.select do |f|
  src = File.binread(f) rescue next
  trailing = trailing0 = true if src.gsub!(/[ \t]+$/, '')
  eofnewline = eofnewline0 = true if src.sub!(/(?<!\n)\z/, "\n")

  expandtab0 = false
  updated_lines = vcs.updated_lines(f)
  if !updated_lines.empty? && (f.end_with?('.c') || f.end_with?('.h') || f == 'insns.def') && EXPANDTAB_IGNORED_FILES.all? { |re| !f.match(re) }
    src.gsub!(/^.*$/).with_index do |line, lineno|
      if updated_lines.include?(lineno) && line.start_with?("\t") # last-committed line with hard tabs
        expandtab = expandtab0 = true
        line.sub(/\A\t+/) { |tabs| ' ' * (8 * tabs.length) }
      else
        line
      end
    end
  end

  if trailing0 or eofnewline0 or expandtab0
    File.binwrite(f, src)
    true
  end
end
unless edited_files.empty?
  msg = [("remove trailing spaces" if trailing),
         ("append newline at EOF" if eofnewline),
         ("translit ChangeLog" if translit),
         ("expand tabs" if expandtab),
        ].compact
  vcs.commit("* #{msg.join(', ')}.#{' [ci skip]' if vcs.ci_skip?}", *edited_files)
end

vcs.commit_properties(*files)
