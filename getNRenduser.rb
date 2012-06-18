#!/usr/bin/env ruby
### grab metrics from newrelic and put them into graphite
### David Lutz
### 2012-06-08

## new versions of ruby don't need the following line
require 'rubygems'
require 'curb'
require 'json'
require 'socket'
require './config.rb'
require './SendGraphite.rb'

if ARGV.length != 2
	puts "I need two arguments. First is the application (e.g. 12345) second is the EndUser field (e.g. average_be_response_time)"
	exit 1
end

application = ARGV[0]
field = ARGV[1]

t=Time.now.utc
timenow=t.to_i
s=t-60

timebegin=s.strftime("%FT%T")
timeend=t.strftime("%FT%T")

metricURL = "https://api.newrelic.com/api/v1/applications/"+application+"/data.json?summary=1&metrics[]=EndUser&field="+field+"&begin="+timebegin+"&end="+timeend

response = Curl::Easy.perform(metricURL) do |curl| curl.headers["x-api-key"] = $apikey
end

body=response.body_str
result = JSON.parse(body)

#result is a JSON array [ blah ] strip off the []s
r3=body[1..-2]

r4=JSON.parse(r3)
message = "newrelic." + r4["app"] + "." + field + " " + r4[field].to_s + " " + timenow.to_s

#puts message 
Sendit message

