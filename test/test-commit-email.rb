require 'test/unit'
require 'shellwords'
require 'tmpdir'
require 'fileutils'
require 'open3'

class TestCommitEmail < Test::Unit::TestCase
  def setup
    @ruby = Dir.mktmpdir
    Dir.chdir(@ruby) do
      git('init')
      git('config', 'user.name', 'David Rodríguez')
      git('config', 'user.email', 'deivid@rodrigu.ez')
      git('commit', '--allow-empty', '-m', 'New repository initialized by cvs2svn.')
      git('commit', '--allow-empty', '-m', 'Initial revision')
      git('commit', '--allow-empty', '-m', 'version 1.0.0')
    end

    @sendmail = File.join(Dir.mktmpdir, 'sendmail')
    File.write(@sendmail, <<~SENDMAIL)
      #!/usr/bin/env ruby
      p ARGV
      puts STDIN.read
    SENDMAIL
    FileUtils.chmod(0755, @sendmail)

    @commit_email = File.expand_path('../bin/commit-email.rb', __dir__)
  end

  # Just testing an exit status :p
  # TODO: prepare something in test/fixtures/xxx and test output
  def test_successful_run
    Dir.chdir(@ruby) do
      out, status = Open3.capture2e(
        { 'SENDMAIL' => @sendmail }, @commit_email, './', 'cvs-admin@ruby-lang.org',
        git('rev-parse', 'HEAD^').chomp, git('rev-parse', 'HEAD').chomp, 'refs/heads/master',
        '--viewer-uri', 'https://github.com/ruby/ruby/commit/',
        '--error-to', 'cvs-admin@ruby-lang.org',
      )
      assert_equal(true, status.success?, out)
    end
  end

  private

  def git(*cmd)
    out, status = Open3.capture2('git', *cmd)
    unless status.success?
      raise "git #{cmd.shelljoin}\n#{out}"
    end
    out
  end
end
