# Ruby commit hook [![Build Status](https://travis-ci.com/ruby/ruby-commit-hook.svg?branch=master)](https://travis-ci.com/ruby/ruby-commit-hook)

## Features

On each commit of Ruby's Git repository, following git hooks are triggered:

### pre-receive

* Verify committer email from `SVN_ACCOUNT_NAME` associated to SSH key used for `git push`
* Reject merge commits (ask @mame about why)

### post-receive

* Send notification to ruby-cvs@ruby-lang.org
* Commit automatic styling:
  * remove trailing spaces
  * append newline at EOF
  * translit ChangeLog
  * expand tabs
* Update version.h if date is changed
* Request Redmine to fetch changesets
* Mirror cgit to GitHub
* Notify committer's Slack

## How this repository is deployed to `git.ruby-lang.org`

* `/data/svn/repos/ruby`: SVN repository of Ruby
  * `hooks/post-commit`: Run `/home/git/ruby-commit-hook/hooks/post-commit.sh`
* `/data/git/ruby.git`: Bare Git repository of ruby
  * `hooks/post-receive`:
     * **Update `/home/git/ruby-commit-hook`**
     * Run `/home/git/ruby-commit-hook/hooks/post-receive.sh`
* `/home/git/ruby-commit-hook`: Cloned Git repository of ruby-commit-hook

### Notes

* There's a symlink `/var/git` -> `/data/git`.
* User `git`'s `$HOME` is NOT `/home/git` but `/var/git`.

## License

[Ruby License](https://www.ruby-lang.org/en/LICENSE.txt)
