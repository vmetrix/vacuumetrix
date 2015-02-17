#!/usr/bin/env ruby
### grab metrics from newrelic and put them into graphite
### David Lutz
### 2012-06-08

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
## new versions of ruby don't need the following line
require 'rubygems' if RUBY_VERSION < "1.9"
require 'curb'
require 'json'

if ARGV.length != 3
        puts "I need three arguments. First is the application (e.g. 12345) second is the metric's name, third is the metric's field (e.g. average_be_response_time)"
        exit 1
end

application = ARGV[0]
metricname = ARGV[1]
field = ARGV[2]

t=Time.now.utc
timenow=t.to_i
s=t-60

timebegin=s.strftime("%FT%T")
timeend=t.strftime("%FT%T")

metricURL = "https://api.newrelic.com/api/v1/applications/"+application+"/data.json?summary=1&metrics[]="+metricname+"&field="+field+"&begin="+timebegin+"&end="+timeend

response = Curl::Easy.perform(metricURL) do |curl|
 curl.headers["x-api-key"] = $newrelicapikey
end

body=response.body_str
result = JSON.parse(body)

r3=result[0]

appname = r3["app"].gsub( /[ \.]/, "_")
metricpath = "newrelic." + appname + "." + metricname + "." + field
metricvalue = r3[field]
metrictimestamp = timenow.to_s

Sendit metricpath, metricvalue, metrictimestamp
