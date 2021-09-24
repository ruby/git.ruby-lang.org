directory '/etc/systemd/system/apache2.service.d' do
  mode  '755'
  owner 'root'
end

remote_file '/etc/systemd/system/apache2.service.d/override.conf' do
  mode  '644'
  owner 'root'
end
