#!/usr/bin/env ruby
### How many facebook likes do we have?
### David Lutz
### 2012-07-23

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
## new versions of ruby don't need the following line
require 'rubygems' if RUBY_VERSION < "1.9"
require 'curb'
require 'json'

if ARGV.length != 1
  puts "I need one arguments. The name of the page."
  exit 1
end

page = ARGV[0]

metricURL = "https://graph.facebook.com/" + page

response = Curl::Easy.perform(metricURL) do |curl|
end

body = response.body_str
result = JSON.parse(body)

metricpath = "facebook.likes." + page
metricvalue = result["likes"]
metrictimestamp = Time.now.utc.to_i.to_s

Sendit metricpath, metricvalue, metrictimestamp
