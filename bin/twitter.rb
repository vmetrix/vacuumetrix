#!/usr/bin/env ruby
### How many twitter followers do we have?
### David Lutz
### 2012-07-23

## new versions of ruby don't need the following line
$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems'
require 'curb'
require 'json'

if ARGV.length != 1
  puts "I need one arguments. The name of the twit."
  exit 1
end

user = ARGV[0]

metricURL = "https://api.twitter.com/1/users/show.json?screen_name=" + user

response = Curl::Easy.perform(metricURL) do |curl| 
end

body = response.body_str
result = JSON.parse(body)

metricpath = "twitter.followers." + user
metricvalue = result["followers_count"]
metrictimestamp = Time.now.utc.to_i.to_s

Sendit metricpath, metricvalue, metrictimestamp
