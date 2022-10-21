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

%w[git svn].each do |subdomain|
  remote_file "/etc/apache2/sites-available/#{subdomain}.ruby-lang.org.conf" do
    mode  '644'
    owner 'root'
    notifies :reload, 'service[apache2]'
  end

  link "/etc/apache2/sites-enabled/#{subdomain}.ruby-lang.org.conf" do
    to "../sites-available/#{subdomain}.ruby-lang.org.conf"
  end
end

%w[ssl cgid].each do |mod|
  %w[conf load].each do |ext|
    link "/etc/apache2/mods-enabled/#{mod}.#{ext}" do
      to "../mods-available/#{mod}.#{ext}"
    end
  end
end
