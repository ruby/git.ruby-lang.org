package "cgit"
package "certbot"
package "git"
package "ruby"
package "postfix"
package "gpg"
package "rsync"

user "git" do
  shell "/usr/bin/git-shell"
end

directory "/home/git" do
  owner "git"
  group "git"
  mode "0755"
end

include_recipe 'apache2'
include_recipe 'git-sync-check'

remote_file '/etc/sudoers'
