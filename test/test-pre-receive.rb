require "test/unit"
require "open3"
require "tmpdir"
require "fileutils"

class TestPreReceive < Test::Unit::TestCase
  def setup
    @svn_account_name = "mame"

    # setup bare repository
    @bare_dir = Dir.mktmpdir
    git("init", "--bare", chdir: @bare_dir)

    # setup working copy
    @working_copy = Dir.mktmpdir
    git("clone", @bare_dir, @working_copy)

    # make the first commit
    make_commit("mame", "mame@ruby-lang.org", "init")
    git("push")

    # deploy the pre-receive hook
    pre_receive = File.join(@bare_dir, "hooks/pre-receive")
    pre_receive_sh = File.join(@bare_dir, "hooks/pre-receive.sh")

    File.write(pre_receive, <<~END)
      #!/bin/bash

      args=""
      while read arg
      do
        args="$args $arg"
      done
      export args

      # Do not use `2>&1` here so that we can show STDERR to pusher.
      exec #{ pre_receive_sh } $args \
        >> /tmp/pre-receive.log
    END
    File.chmod(0755, pre_receive)

    pre_receive_sh = File.join(@bare_dir, "hooks/pre-receive.sh")
    src = File.read(File.join(__dir__, "../hooks/pre-receive.sh"))
    src = src.sub(/^ruby_git=.*/) { "ruby_git=#{ @bare_dir }" }
    src = src.sub(/^ruby_commit_hook=.*/) { "ruby_commit_hook=#{ File.join(__dir__, "..") }" }
    File.write(pre_receive_sh, src)
    File.chmod(0755, pre_receive_sh)
  end

  def teardown
    FileUtils.remove_entry(@bare_dir) if @bare_dir
    FileUtils.remove_entry(@working_copy) if @working_copy
  end

  def git(*cmd, chdir: @working_copy)
    env = { "SVN_ACCOUNT_NAME" => @svn_account_name }
    out, status = Open3.capture2e(env, "git", *cmd, chdir: chdir)
    unless status.success?
      raise "git #{ cmd.join(" ") }\n" + out
    end
  end

  def make_commit(user, email, file)
    git("config", "--local", "user.name", user)
    git("config", "--local", "user.email", email)
    File.write(File.join(@working_copy, file), file)
    git("add", file)
    git("commit", "-m", file)
  end

  def test_check_right_svn_account
    make_commit("mame", "mame@ruby-lang.org", "test")
    git("push")
  end

  def test_check_wrong_svn_account
    make_commit("foo", "foo@example.com", "test")
    err = git("push") rescue $!
    assert_match(
      /The git committer email \(foo@example\.com\) does not seem to be mame's email \(mame@ruby-lang\.org\)\./,
      err.message
    )
  end

  def test_push_multiple_commits
    make_commit("mame", "mame@ruby-lang.org", "test-1")
    make_commit("mame", "mame@ruby-lang.org", "test-2")
    make_commit("mame", "mame@ruby-lang.org", "test-3")
    git("push")
  end

  def test_push_multiple_commits_including_wrong_committer
    make_commit("foo", "foo@example.com", "evil-commit")
    make_commit("mame", "mame@ruby-lang.org", "test")
    err = git("push") rescue $!
    assert_match(
      /The git committer email \(foo@example\.com\) does not seem to be mame's email \(mame@ruby-lang\.org\)\./,
      err.message
    )
  end

  def test_prohibit_merge_commit
    #           .-- c -- d -- e
    #          /        /
    # init -- a -- b --'
    make_commit("mame", "mame@ruby-lang.org", "a")
    git("branch", "topic")
    make_commit("mame", "mame@ruby-lang.org", "b")
    git("checkout", "topic")
    make_commit("mame", "mame@ruby-lang.org", "c")
    git("checkout", "master")
    git("merge", "topic", "-m", "d")
    make_commit("mame", "mame@ruby-lang.org", "e")
    err = git("push") rescue $!
    assert_match(
      /A merge commit is prohibited\./,
      err.message
    )
  end
end
