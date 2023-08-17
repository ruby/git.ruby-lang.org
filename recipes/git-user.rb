user "git" do
  shell "/usr/bin/git-shell"
end

remote_file "/var/git/.ssh/authorized_keys" do
  mode  "600"
  owner "git"
end
