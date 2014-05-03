#
# Cookbook Name:: ghost
# Attributes:: default
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

# User and group
node.default['ghost']['user']['name'] = 'ghost'
node.default['ghost']['user']['home'] = '/home/ghost'
node.default['ghost']['user']['shell'] = '/bin/bash'
node.default['ghost']['group']['name'] = 'ghost'

# App server settings
node.default['ghost']['version'] = '0.4.2'
node.default['ghost']['path'] = '/srv/ghost'

# App settings
node.default['ghost']['app']['name'] = 'ghost'
node.default['ghost']['app']['url'] = 'http://0.0.0.0'
node.default['ghost']['app']['server']['host'] = '0.0.0.0'
node.default['ghost']['app']['server']['hostnames'] = 'localhost'
node.default['ghost']['app']['server']['port'] = 2368

# Mail settings
node.default['ghost']['app']['mail'] = {}

# Nginx overrides
node.override['nginx']['default_site_enabled'] = false
