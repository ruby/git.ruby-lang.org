#!/usr/bin/env ruby
# Usage:
#   auto-style.rb [repo_path] [args...]

require 'shellwords'
require 'tmpdir'
ENV['LC_ALL'] = 'C'

class Git
  def initialize(oldrev, newrev, branch)
    @oldrev = oldrev
    @newrev = newrev
    @branch = branch
  end

  # ["foo/bar.c", "baz.h", ...]
  def updated_paths
    with_clean_env do
      IO.popen(['git', 'diff', '--name-only', @oldrev, @newrev], &:readlines).each(&:chomp!)
    end
  end

  # [0, 1, 4, ...]
  def updated_lines(file)
    lines = []
    with_clean_env { IO.popen(['git', 'blame', file], &:readlines) }.each_with_index do |line, index|
      # git 2.1.4 on git@git.ruby-lang.org shows only 8 chars on blame.
      if line[0..7] == @newrev[0..7]
        lines << index
      end
    end
    lines
  end

  def commit(log, *files)
    git('add', *files)
    git('commit', '-m', log)
    git('push', 'origin', @branch)
  end

  def ci_skip?
    unless defined?(@ci_skip)
      @ci_skip = (true if /\[ci skip\]/i =~ with_clean_env {IO.popen(['git', 'log', '-n1', @newrev]) {|f| f.gets(''); f.gets}})
    end
    @ci_skip
  end

  private

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

EXPANDTAB_IGNORED_FILES = [
  # vendoring
  %r{\Accan/},
  %r{\Aext/bigdecimal/},
  %r{\Aext/nkf/},
  %r{\Aext/io/},
  %r{\Aext/json/},
  %r{\Aext/psych/},
  %r{\Aext/stringio/},

  # vendoring (bundler)
  %r{\Abin/bundler\z},
  %r{\Alib/bundler/},

  # vendoring (onigmo)
  %r{\Aenc/},
  %r{\Ainclude/ruby/onigmo\.h\z},
  %r{\Areg.+\.(c|h)\z},

  # explicit or implicit `c-file-style: "linux"`
  %r{\Aaddr2line\.c\z},
  %r{\Amissing/},
  %r{\Astrftime\.c\z},
  %r{\Avsnprintf\.c\z},
]

repo_path, *rest = ARGV
rest.each_slice(3).map do |oldrev, newrev, refname|
  branch = IO.popen(['git', 'rev-parse', '--symbolic', '--abbrev-ref', refname], &:read).strip
  next if branch != 'trunk' # Stable branches are on svn, and for consistency we should not make a git-specific commit.
  vcs = Git.new(oldrev, newrev, branch)

  Dir.mktmpdir do |workdir|
    depth = IO.popen(['git', 'log', '--pretty=%H', "#{oldrev}..#{newrev}"], &:read).lines.size + 1
    system "git clone --depth=#{depth} --branch=#{branch} file:///#{repo_path} #{workdir}"
    Dir.chdir(workdir)

    paths = vcs.updated_paths
    paths.select! {|l|
      /^\d/ !~ l and /\.bat\z/ !~ l and
      (/\A(?:config|[Mm]akefile|GNUmakefile|README)/ =~ File.basename(l) or
       /\A\z|\.(?:[chsy]|\d+|e?rb|tmpl|bas[eh]|z?sh|in|ma?k|def|src|trans|rdoc|ja|en|el|sed|awk|p[ly]|scm|mspec|html|)\z/ =~ File.extname(l))
    }
    files = paths.select {|n| File.file?(n)}
    next if files.empty?

    translit = trailing = eofnewline = expandtab = false

    files.grep(/\/ChangeLog\z/) do |changelog|
      if IO.foreach(changelog, 'rb').any? { |line| !line.ascii_only? }
        tmp = "#{changelog}.ascii"
        if system('iconv', '-f', 'utf-8', '-t', 'us-ascii//translit', changelog, out: tmp) and
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
      msg = [('remove trailing spaces' if trailing),
             ('append newline at EOF' if eofnewline),
             ('translit ChangeLog' if translit),
             ('expand tabs' if expandtab),
            ].compact
      vcs.commit("* #{msg.join(', ')}.#{' [ci skip]' if vcs.ci_skip?}", *edited_files)
    end
  end
end
