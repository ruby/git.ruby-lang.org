execute 'systemctl daemon-reload' do
  action :nothing
end

remote_file '/etc/systemd/system/git-sync-check.service' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload]'
end

remote_file '/etc/systemd/system/git-sync-check.timer' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload]'
end

service 'git-sync-check.timer' do
  action :start
end

link '/etc/systemd/system/timers.target.wants/git-sync-check.timer' do
  to '/etc/systemd/system/git-sync-check.timer'
end
