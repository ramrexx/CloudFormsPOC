#!/bin/bash
# /var/www/miq/knife_wrapper.sh

# you MUST have this or you will get errors
unset GEM_HOME GEM_PATH IRBRC MY_RUBY_HOME

#USER=admin

# path to knife configuration file
/usr/bin/knife $@ --config /root/.chef/knife.rb
