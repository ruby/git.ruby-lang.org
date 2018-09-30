#!/usr/bin/env ruby
#
# Usage:
#   auto-style.rb [directory] # svn mode
#   RUBY_GIT_HOOK=0 auto-style.rb [directory] # svn mode
#   RUBY_GIT_HOOK=1 auto-style.rb [directory] # git mode
#

ENV["LC_ALL"] = "C"

class SVN
  def svnread(*args)
    IO.popen(["svn", *args], &:readlines).each(&:chomp!)
  end

  def update(*args)
    log = svnread("update", "--accept=postpone", *args)
    log[1...-1].grep(/^[AMU]/) {|l| l[5..-1]}
  end

  def commit(log, *args)
    exec("ci", "-m", log, *args)
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
    vcs.commit("* properties.", *files)
  end

  def last_rev
    svnread('log', '-r', 'HEAD', '-q')[1].match(/\Ar(?<rev>\d+) /)[:rev]
  end

  private

  def exec(*args)
    system("svn", *args)
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
end

if ENV['RUBY_GIT_HOOK'] == '1'
  vcs = Git.new
else
  vcs = SVN.new

  if ARGV[0] == "--debug"
    ARGV.shift
    vcs.extend(SVN::Debugging)
  end
end

unless ARGV.empty?
  Dir.chdir(ARGV.shift)
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

log = vcs.update
log.select! {|l|
  /^\d/ !~ l and /\.bat\z/ !~ l and
  (/\A(?:config|[Mm]akefile|GNUmakefile|README)/ =~ File.basename(l) or
   /\A\z|\.(?:[chsy]|\d+|e?rb|tmpl|bas[eh]|z?sh|in|ma?k|def|src|trans|rdoc|ja|en|el|sed|awk|p[ly]|scm|mspec|html|)\z/ =~ File.extname(l))
}
files = log.select {|n| File.file?(n)}
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

last_rev = vcs.last_rev
edit = files.select do |f|
  src = File.binread(f) rescue next
  trailing = trailing0 = true if src.gsub!(/[ \t]+$/, '')
  eofnewline = eofnewline0 = true if src.sub!(/(?<!\n)\z/, "\n")

  expandtab0 = false
  if last_rev && (f.end_with?('.c') || f.end_with?('.h') || f == 'insns.def') && EXPANDTAB_IGNORED_FILES.all? { |re| !f.match(re) }
    line_i = 0
    blames = vcs.svnread('blame', f)
    src.gsub!(/^.*$/) do |line|
      blame = blames[line_i]
      line_i += 1
      if blame.match(/\A\s*#{last_rev}\s/) && line.start_with?("\t") # last-committed line with hard tabs
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
unless edit.empty?
  msg = [("remove trailing spaces" if trailing),
         ("append newline at EOF" if eofnewline),
         ("translit ChangeLog" if translit),
         ("expand tabs" if expandtab),
        ].compact
  vcs.commit("* #{msg.join(', ')}.", *edit)
end

vcs.commit_properties(*files)
