# ghost-cookbook

A [Chef](http://getchef.com/) cookbook for building and managing a [Ghost blog](http://docs.ghost.org/). 

## Features

  * Easily install new versions of Ghost by setting a version number in an attribute
  * Optionally merge with your own public or private Git repository to incorporate themes or customizations
  * Keep it simple with [SQLite](http://sqlite.org/) as the database
  * Use [Test Kitchen](http://kitchen.ci/) and [ServerSpec](http://serverspec.org/) for BDD awesomeness

## Supported Platforms

  * Ubuntu >= 12.04
  * CentOS >= 6.5

## Overview

[Ghost](http://docs.ghost.org/) is a great little blog engine, but it's not the easiest thing to work with if you're a Web developer into configuration management.  Installing new versions [is a pain](http://docs.ghost.org/installation/upgrading/), there's no great way to customize a theme, and it doesn't suggest much of a workflow for keeping your site under revision control.  This cookbook aims to fix all that by letting you work locally, test locally, commit to Github and use Chef to bring everything together, deploy and manage it.

### Assumptions

This cookbook assumes a few things you should keep in mind: 

  * It relies primarily on attributes, so it's currently one blog per node.  Future versions might accomodate multiple blogs running on different ports, but for now, we're assuming you're okay with that.

  * You don't mind running SQLite in production.  Some people have a philosophical issue with this, but most shouldn't: unless you're running a blog that's being updated very actively by multiple authors concurrently, or exceeding a million requests per day, it's unlikely you'll ever notice a problem &mdash; SQLite is fast and very happy to be flooded with reads.  That said, I'll probably add an RDBMS recipe at some point, but I personally enjoy the simplicity and portability of a flat-file database, so that's what we have today.  

  * Remote (content) repositories are presumed public by default.  If you'd like to pull from a private (e.g., Github) repo, you'll need to generate a deployment key and add it to a ``chef-vault`` secret at ``vault/secrets/ghost/deploy-key``.  See the Workflow section below for specifics on how to do this. 

  * Backups are up to you.  I plan to include a recipe that addresses the obvious need to account for and capture content changes in production, but it's not there yet. 

  * You're using a Chef server.  Don't have one?  [Use Chef's](https://manage.opscode.com/signup). (It's free!)  New to Chef?  [Start learning here](https://learnchef.opscode.com/).

### Workflow

All you really need to do is upload this cookbook and its dependencies to your Chef server and run it; with only the default attributes, the ``default`` recipe alone will procuce a Ghost blog running on port 2368, and adding the ``nginx`` recipe will set up an [Nginx](http://nginx.org/en/) server to proxy and expose it over port 80. (See below for a pasteable snippet that bootstraps a new node with both on [Amazon EC2](http://aws.amazon.com/).)

Use the ``ghost-blog`` role (see ``test/integration/roles/ghost-blog.json`` for an example) as a shortcut to both set that run list and override any attributes you might prefer &mdash; e.g., to pull from a [public repo I've set up](https://github.com/cnunciato/ghost-content) containing a handful of free Ghost themes as a convenient jumping-off point:

    {
      "name": "ghost-blog",
      "chef_type": "role",
      "json_class": "Chef::Role",
      "override_attributes": {
        "ghost": {
          "remote": {
            "name": "ghost-content",
            "repo": "https://github.com/cnunciato/ghost-content.git",
            "revision": "master"
          }
        }
      },
      "run_list": [
        "recipe[ghost]",
        "recipe[ghost::nginx]"
      ]
    }

If you'd like to be able to develop locally and keep your changes under revision control, you'll need to [download and install Ghost](https://ghost.org/download/), create a repository from that, commit your changes and push to your remote, and then specify that remote as an override attribute &mdash; e.g., by modifying the ``ghost-blog`` role from above:

    {
      "name": "ghost-blog",
      ...
      "override_attributes": {
        "ghost": {
          "remote": {
            "name": "your-repo",
            "repo": "https://github.com/yourusername/your-repo.git",
            "revision": "master"
          }
        }
      },
      ...
    } 

In the example above, the assumption is that your repository is public, which doesn't work for everyone.  If you'd like to pull from a private repo (e.g., it's a work thing, or you've got some paid themes you'd like to protect as a good citizen of the Internet), then you'll need &mdash; **after** your initial bootstrap (that's how chef-vault works) &mdash; to:

  * [Install chef-vault](https://github.com/Nordstrom/chef-vault)
  * [Create a new SSH key pair](https://help.github.com/articles/generating-ssh-keys)
  * [Add the public key to your Github repo](https://help.github.com/articles/managing-deploy-keys) 
  * Add the private key to a secrets file (e.g., ``data_bags/vault/secrets.json``)
  * Create a new chef-vault secret with that file and expose the secret to your blog's (already created) node
  * Update your node to use this new, private repo instead

For example:

    gem install chef-vault
    ssh-keygen -t rsa "you@yourdomain.com" # and make sure you leave the passphrase blank

Create ``data_bags/vault/secrets.json``, add your private key to it, then:

    knife vault create vault secrets \
      --json data_bags/vault/secrets.json \
      --search 'role:ghost-blog' \
      --admins 'yourchefusername'
      --mode client

Update the role to use the new repo:

    {
      "name": "ghost-blog",
      ...
      "override_attributes": {
        "ghost": {
          "remote": {
            "name": "your-private-repo",
            "repo": "git@github.com:yourusername/your-private-repo.git",
            "revision": "master"
          }
        }
      },
      ...
    } 

And then run ``chef-client`` to pick up the changes: 

    knife ssh 'role:ghost-blog' 'sudo chef-client'

See ``test/integration/data_bags/vault/secrets.json`` for an example of the expected structure of ``secrets.json`` &mdash;just supply your (private, line-break-escaped) deploy key as the ``deploy-key`` value and you should be good to go. See the [chef-vault documentation](https://github.com/Nordstrom/chef-vault) for additional details and examples.

## Attributes

See ``attributes/default.rb`` for the set of default attributes.  You can also specify additional/override attributes for mail-server settings, or to set your remote content repository as described above:

    {
      "name": "ghost-blog",
      ...
      "override_attributes": {
        "ghost": {
          "app": {
            "mail": {
              "transport": "SMTP",
              "options": {
                "service": "Gmail",
                "auth": {
                  "user": "your-designated-blog-email-address@gmail.com",
                  "pass": "your-designated-blog-email-password"
                }
              }
            }
          },
          "remote": {
            "name": "your-private-repo",
            "repo": "git@github.com:yourusername/your-private-repo.git",
            "revision": "master"
          }
        }
      },
      ...
    } 

## Tests

If you're running [VirtualBox](https://www.virtualbox.org/) and [Vagrant](http://www.vagrantup.com/), you can:

    bundle install

... then run Test Kitchen and ServerSpec to verify Chef builds your node as you expect:

    kitchen converge
    kitchen verify

## Issues

Bugs, features, comments?  Use [Github Issues](https://github.com/cnunciato/ghost-cookbook/issues).

## A Quick Snip to Get Up and Running on EC2

Once you've got Chef installed, ``knife`` configured, and this cookbook (and its dependencies) uploaded to your Chef server, just swap in the path to your own EC2 key and go:

    knife ec2 server create \
      --flavor t1.micro \
      --image ami-018c9568 \
      --availability-zone us-east-1d \
      --identity-file ~/.ssh/your-us-east-key.pem \
      --ssh-user ubuntu \
      --node-name 'my-ghost-blog' \
      --run-list 'recipe[ghost],recipe[ghost::nginx]'

This'll give you an Ubuntu 12.04 EBS-backed micro-instance running on port 80.  (The [usual charges](http://aws.amazon.com/ec2/instance-types/) may apply, of course.)

## Author

Author:: Christian Nunciato (<chris@nunciato.org>)
