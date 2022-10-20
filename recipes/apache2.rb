execute 'systemctl daemon-reload' do
  action :nothing
end

directory '/etc/systemd/system/apache2.service.d' do
  mode  '755'
  owner 'root'
end

remote_file '/etc/systemd/system/apache2.service.d/override.conf' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload]'
  notifies :restart, 'service[apache2]'
end

service 'apache2' do
  action :nothing
end

remote_file '/etc/apache2/sites-available/git.ruby-lang.org.conf' do
  mode  '644'
  owner 'root'
  notifies :reload, 'service[apache2]'
end

link '/etc/apache2/sites-enabled/git.ruby-lang.org.conf' do
  to '../sites-available/git.ruby-lang.org.conf'
end

link '/etc/apache2/mods-enabled/ssl.conf' do
  to '../mods-available/ssl.conf'
end

link '/etc/apache2/mods-enabled/ssl.load' do
  to '../mods-available/ssl.load'
end

link '/etc/apache2/mods-enabled/cgid.conf' do
  to '../mods-available/cgid.conf'
end

link '/etc/apache2/mods-enabled/cgid.load' do
  to '../mods-available/cgid.load'
end
