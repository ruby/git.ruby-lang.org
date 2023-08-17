user "git" do
  shell "/usr/bin/git-shell"
  home "/var/git"
end

# We put files used by git here. However, this is NOT git's $HOME.
directory "/home/git" do
  owner "git"
  group "git"
  mode "0755"
end

remote_file "/var/git/.ssh/authorized_keys" do
  mode  "600"
  owner "git"
end

remote_file "/var/git/.gitconfig" do
  mode  "644"
  owner "git"
end
