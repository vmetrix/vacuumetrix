#!/usr/bin/env ruby
## Count how many of each type of EC2 instance we're running
## This works well as a stacked graph 
### David Lutz
### 2012-07-16
### gem install fog  --no-ri --no-rdoc
 
require 'rubygems'
require 'fog'
require '/opt/vacuumetrix/conf/config.rb'
require '/opt/vacuumetrix/lib/Sendit.rb'

compute = Fog::Compute.new(:provider => :aws, :aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)
instance_list = compute.servers.all
instance_report = Hash.new

instance_list.each do |i|
  if  instance_report[i.flavor_id].nil? 
    instance_report[i.flavor_id] = 1
  else
    instance_report[i.flavor_id] = instance_report[i.flavor_id] + 1
  end
end

instance_report.each do |itype, count|
  metricpath = "AWScountEC2" + "." + itype.gsub(".","_")
  metricvalue = count
  metrictimestamp=Time.now.utc.to_i.to_s
  Sendit metricpath, metricvalue, metrictimestamp
end


