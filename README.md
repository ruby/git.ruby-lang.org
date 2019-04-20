# Ruby commit hook [![Build Status](https://travis-ci.com/ruby/ruby-commit-hook.svg?branch=master)](https://travis-ci.com/ruby/ruby-commit-hook)

## How this repository is deployed to `git.ruby-lang.org`

* `/data/svn/repos/ruby`: SVN repository of Ruby
  * `hooks/post-commit`: Run `/home/git/ruby-commit-hook/hooks/post-commit.sh`
* `/data/git/ruby.git`: Bare Git repository of ruby
  * `hooks/post-receive`:
     * **Update `/home/git/ruby-commit-hook`**
     * Run `/home/git/ruby-commit-hook/hooks/post-receive.sh`
* `/data/git/ruby-commit-hook.git`: Bare Git repository of ruby-commit-hook
* `/home/git/ruby-commit-hook`: Cloned Git repository of ruby-commit-hook

### Notes

* There's a symlink `/var/git` -> `/data/git`.
* User `git`'s `$HOME` is NOT `/home/git` but `/var/git`.

### Script used to update `/home/git/ruby-commit-hook`

```
/usr/bin/git -C /home/git/ruby-commit-hook fetch origin master
/usr/bin/git -C /home/git/ruby-commit-hook checkout origin/master
```
