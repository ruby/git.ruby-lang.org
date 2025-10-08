# git.ruby-lang.org ![test](https://github.com/ruby/git.ruby-lang.org/workflows/test/badge.svg)

## Features

On each commit of Ruby's Git repository, following git hooks are triggered:

### pre-receive

* Verify committer email from `SVN_ACCOUNT_NAME` associated to SSH key used for `git push`
* Reject merge commits (ask @mame about why)

### post-receive

* Send notification to ruby-cvs@ruby-lang.org
* Request Redmine to fetch changesets

## The directory structure of `git.ruby-lang.org`

* `/data/git/ruby.git`: Bare Git repository of ruby
  * `hooks/post-receive`: Run `/home/git/git.ruby-lang.org/hooks/post-receive.sh`
* `/home/git/git.ruby-lang.org`: Cloned Git repository of git.ruby-lang.org

### Notes

* There's a symlink `/var/git` -> `/data/git`.
* User `git`'s `$HOME` is NOT `/home/git` but `/var/git`.

## How to deploy `ruby/git.ruby-lang.org`

### Authentication

* We use only `admin` user for `git.ruby-lang.org`'s SSH access.
  * You should contact @hsbt, @mame or @k0kubun for accessing `git.ruby-lang.org`.

### recipes

```bash
# dry-run
bin/hocho apply -n git.ruby-lang.org

# apply
bin/hocho apply git.ruby-lang.org
```

### TODO for recipes for git.ruby-lang.org

* How to store `ssh_host_key*` and `sshd_config` safely?
* How to write a recipe to mount data volume for bare git repository?
* How to write a recipe for mackerel with the host key of git.ruby-lang.org?

## License

[Ruby License](./license.txt)
