#!/usr/bin/env ruby
### How many twitter followers do we have?
### David Lutz
### 2012-07-23
###
### Moved to api v1.1 as v1 is deprecated
### 2013-12-07

## new versions of ruby don't need the following line
$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems'
require 'twitter'

if ARGV.length != 1
  puts "I need one argument, the name of the twitter user."
  exit 1
end

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = $tw_consumer_key
  config.consumer_secret     = $tw_consumer_secret
  config.access_token        = $tw_access_token
  config.access_token_secret = $tw_access_token_secret
end

user = ARGV[0]

user_object		= client.user(user)
followers_count	= user_object.followers_count

metricpath = "twitter.followers." + user
metricvalue = followers_count
metrictimestamp = Time.now.utc.to_i.to_s

Sendit metricpath, metricvalue, metrictimestamp
