#!/usr/bin/env ruby
## grab metrics from Neustar
### David Lutz
### 2012-07-22
# Neustar API example code https://apidocs.wpm.neustar.biz/

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems'
require 'json'
require 'digest/md5'
require 'curb'
require 'time'

$startTime = Time.now.utc-3600
$endTime  = Time.now.utc-1800

current_time = Time.now
timestamp = Time.now.to_i.to_s
$sig = Digest::MD5.hexdigest( $neustarkey+$neustarsecret+timestamp )

def lookupNeustarSamples(id, name)
  samplesURL = "http://api.neustar.biz/performance/monitor/1.0/#{id}/sample?startDate=#{$startTime.strftime("%FT%H:%M")}&endDate=#{$endTime.strftime("%FT%H:%M")}&apikey=#{$neustarkey}&sig=#{$sig}"

  response = Curl::Easy.perform(samplesURL) do |curl| 
  end

  samplesbody=response.body_str
  samplesresult = JSON.parse(samplesbody)
  data =  samplesresult["data"]
  items =  data["items"]

  items.each do |i|
    if i["status"] == "SUCCESS"
      startTime = i["startTime"] + " UTC"
      metricpath = "neustar." + name.gsub(" ","_") + "." + i["location"] + "." + "duration"
      metricvalue = i["duration"]
      metrictimestamp = Time.parse(startTime).to_i.to_s
      Sendit metricpath, metricvalue, metrictimestamp
    end
    if i["status"] == "ERROR"
      metricpath = "neustar." + name.gsub(" ","_") + "." + i["location"] +"." +  "error"
      Sendit metricpath, "1" , metrictimestamp
    end

  end 

end


metricURL = "http://api.neustar.biz/performance/monitor/1.0?apikey=#{$neustarkey}&sig=#{$sig}"

response = Curl::Easy.perform(metricURL) do |curl| 
end

body=response.body_str
result = JSON.parse(body)
data =  result["data"]
items =  data["items"]

items.each do |i|
  lookupNeustarSamples i["id"], i["name"]
end
