#!/usr/bin/env ruby
### grab metrics from newrelic and put them into graphite
### David Lutz
### 2012-06-08

## new versions of ruby don't need the following line
require 'rubygems'
require 'curb'
require 'json'
require 'socket'
require '/opt/vacuumetrix/conf/config.rb'
require '/opt/vacuumetrix/lib/Sendit.rb'

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

response = Curl::Easy.perform(metricURL) do |curl| curl.headers["x-api-key"] = $newrelicapikey
end


body=response.body_str
result = JSON.parse(body)

r3=result[0]

metricpath = "newrelic." + r3["app"] + "." + field 
metricvalue = r3[field]
metrictimestamp = timenow.to_s

Sendit metricpath, metricvalue, metrictimestamp
