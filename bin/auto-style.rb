#!/usr/bin/env ruby
# Usage:
#   auto-style.rb [repo_path] [args...]

require 'shellwords'
require 'tmpdir'
ENV['LC_ALL'] = 'C'

class Git
  attr_reader :depth

  def initialize(oldrev, newrev, branch)
    @oldrev = oldrev
    @newrev = newrev
    @branch = branch
    with_clean_env do
      @revs = IO.popen(['git', 'log', '--format=%H', "#{@oldrev}..#{@newrev}"], &:readlines).map(&:chomp!)
      @depth = @revs.size
    end
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
    revs_pattern = /\A(?:#{@revs.join('|')}) /
    with_clean_env { IO.popen(['git', 'blame', '-l', '--', file], &:readlines) }.each_with_index do |line, index|
      if revs_pattern =~ line
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

DEFAULT_GEM_LIBS = %w[
  bundler
  cmath
  csv
  e2mmap
  fileutils
  forwardable
  ipaddr
  irb
  logger
  matrix
  mutex_m
  ostruct
  prime
  rdoc
  rexml
  rss
  scanf
  shell
  sync
  thwait
  tracer
  webrick
]

DEFAULT_GEM_EXTS = %w[
  bigdecimal
  date
  dbm
  etc
  fcntl
  fiddle
  gdbm
  io/console
  json
  openssl
  psych
  racc
  sdbm
  stringio
  strscan
  zlib
]

IGNORED_FILES = [
  # default gems whose master is GitHub
  %r{\Abin/(?!erb)\w+\z},
  *(DEFAULT_GEM_LIBS + DEFAULT_GEM_EXTS).flat_map { |lib|
    [
      %r{\Alib/#{lib}/},
      %r{\Alib/#{lib}\.gemspec\z},
      %r{\Alib/#{lib}\.rb\z},
      %r{\Atest/#{lib}/},
    ]
  },
  *DEFAULT_GEM_EXTS.flat_map { |ext|
    [
      %r{\Aext/#{ext}/},
      %r{\Atest/#{ext}/},
    ]
  },

  # vendoring (ccan)
  %r{\Accan/},

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
  branch = IO.popen({ 'GIT_DIR' => repo_path }, ['git', 'rev-parse', '--symbolic', '--abbrev-ref', refname], &:read).strip
  next if branch != 'master' # Stable branches are on svn, and for consistency we should not make a git-specific commit.
  vcs = Git.new(oldrev, newrev, branch)

  Dir.mktmpdir do |workdir|
    depth = vcs.depth + 1
    system "git clone --depth=#{depth} --branch=#{branch} file:///#{repo_path} #{workdir}"
    Dir.chdir(workdir)

    paths = vcs.updated_paths
    paths.select! {|l|
      /^\d/ !~ l and /\.bat\z/ !~ l and
      (/\A(?:config|[Mm]akefile|GNUmakefile|README)/ =~ File.basename(l) or
       /\A\z|\.(?:[chsy]|\d+|e?rb|tmpl|bas[eh]|z?sh|in|ma?k|def|src|trans|rdoc|ja|en|el|sed|awk|p[ly]|scm|mspec|html|)\z/ =~ File.extname(l))
    }
    files = paths.select {|n| File.file?(n) }
    files.reject! do |f|
      IGNORED_FILES.any? { |re| f.match(re) }
    end
    next if files.empty?

    trailing = eofnewline = expandtab = false

    edited_files = files.select do |f|
      src = File.binread(f) rescue next
      trailing = trailing0 = true if src.gsub!(/[ \t]+$/, '')
      eofnewline = eofnewline0 = true if src.sub!(/(?<!\n)\z/, "\n")

      expandtab0 = false
      updated_lines = vcs.updated_lines(f)
      if !updated_lines.empty? && (f.end_with?('.c') || f.end_with?('.h') || f == 'insns.def')
        # If and only if unedited lines did not have tab indentation, prevent introducing tab indentation to the file.
        expandtab_allowed = src.each_line.with_index.all? do |line, lineno|
          updated_lines.include?(lineno) || !line.start_with?("\t")
        end

        if expandtab_allowed
          src.gsub!(/^.*$/).with_index do |line, lineno|
            if updated_lines.include?(lineno) && line.start_with?("\t") # last-committed line with hard tabs
              expandtab = expandtab0 = true
              line.sub(/\A\t+/) { |tabs| ' ' * (8 * tabs.length) }
            else
              line
            end
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
             ('expand tabs' if expandtab),
            ].compact
      message = "* #{msg.join(', ')}. [ci skip]"
      if expandtab
        message += "\n\nTabs were expanded because the file did not have any tab indentation in unedited lines."
        message += "\nPlease update your editor config, and use misc/expand_tabs.rb in the pre-commit hook."
      end
      vcs.commit(message, *edited_files)
    end
  end
end
