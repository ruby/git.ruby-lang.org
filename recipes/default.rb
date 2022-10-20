package "cgit"
package "certbot"
package "git"
package "ruby"
package "postfix"
package "gpg"
package "rsync"

include_recipe 'apache2'
include_recipe 'git-sync-check'

remote_file '/etc/sudoers'
