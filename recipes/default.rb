#
# Cookbook Name:: ghost
# Recipe:: default
#
# Copyright (C) 2014 Christian Nunciato
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'apt'
include_recipe 'build-essential'
include_recipe 'git'
include_recipe 'nodejs::install_from_binary'
include_recipe 'sqlite'
include_recipe 'runit'
include_recipe 'chef-vault'

package 'unzip'

user = node['ghost']['user']
group = node['ghost']['group']
ghost_version = node['ghost']['version']
install_path = node['ghost']['path']
content_remote = node['ghost']['remote']

deploy_key = begin
  chef_vault_item('vault', 'secrets')['ghost']['deploy-key']
rescue
  nil
end

ghost_release_zip_source = "https://github.com/TryGhost/Ghost/releases/download/#{ghost_version}/Ghost-#{ghost_version}.zip"
ghost_release_zip_path = "#{install_path}/releases/#{ghost_version}.zip"
all_releases_path = "#{install_path}/releases"
this_release_path = "#{install_path}/releases/#{ghost_version}"
release_content_path = "#{this_release_path}/content"
shared_content_path = "#{install_path}/content"

user user['name'] do
  home user['home']
  shell user['shell']
  action :create
end

group group['name'] do
  members user['name']
end

[user['home'], "#{user['home']}/.ssh", install_path, all_releases_path, shared_content_path].each do |name|
  directory name do
    owner user['name']
    group group['name']
    recursive true
  end
end

remote_file ghost_release_zip_path do
  source ghost_release_zip_source
  owner user['name']
  group group['name']
  notifies :run, 'execute[unzip]', :immediately
end

execute 'unzip' do
  cwd all_releases_path
  user user['name']
  command "unzip #{ghost_release_zip_path} -d #{ghost_version}"
  action :nothing
  notifies :create, 'ruby_block[prepare-content]', :immediately
end

ruby_block 'prepare-content' do
  block do
    Dir.glob("#{release_content_path}/*").each do |f|
      if File.directory?(f) && !Dir.exists?("#{shared_content_path}/#{File.basename(f)}")
        FileUtils.cp_r(f, shared_content_path)
      end
    end
    FileUtils.chown_R(user['name'], group['name'], shared_content_path)
    FileUtils.mv(release_content_path, "#{release_content_path}.bak")
  end
  action :nothing
  notifies :create, 'link[shared-content]', :immediately
end

link 'shared-content' do
  target_file release_content_path
  to shared_content_path
  owner user['name']
  group group['name']
  action :nothing
  notifies :run, 'execute[npm-install]', :immediately
end

if content_remote
  remote_repo = content_remote['repo']
  remote_revision = content_remote['revision'] || 'master'
  remote_destination = "#{Chef::Config[:file_cache_path]}/{content_remote['name']}"

  if deploy_key
    key_path = "#{user['home']}/.ssh/id_rsa"
    wrapper_path = key_path ? "#{user['home']}/.ssh/deploy_wrapper.sh" : nil

    file key_path do
      owner user['name']
      group user['name']
      content deploy_key
      mode 0600
    end

    template wrapper_path do
      source 'ssh_wrapper.sh.erb'
      owner user['name']
      group user['name']
      variables({ 'key_path' => key_path })
      mode 0770
    end
  end
  
  git remote_destination do
    repository remote_repo
    revision remote_revision
    ssh_wrapper wrapper_path
    only_if { remote_repo }
    notifies :run, 'execute[copy-remote-content]', :immediately
  end

  execute 'copy-remote-content' do
    cwd remote_destination
    user user['name']
    command "cp -R content/* #{shared_content_path}/"
    action :nothing
    notifies :restart, 'service[ghost]', :delayed
  end

end

execute 'npm-install' do
  cwd this_release_path
  user user['name']
  group group['name']
  environment({ 'HOME' => user['home'] })
  command "npm install --production"
  action :nothing
  notifies :restart, 'service[ghost]', :delayed
end

template 'config' do
  source 'config.js.erb'
  path "#{this_release_path}/config.js"
  variables node['ghost']['app']
  notifies :restart, 'service[ghost]', :delayed
end

runit_service 'ghost' do
  default_logger true
  options({ 'release_path' => this_release_path, 'user' => user['name'] })
end
