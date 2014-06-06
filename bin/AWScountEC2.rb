#!/usr/bin/env ruby
## Count how many of each type of EC2 instance we're running
## This works well as a stacked graph
### David Lutz
### 2012-07-16
### gem install fog  --no-ri --no-rdoc

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'

compute = Fog::Compute.new($awscredential.merge({:provider => :aws}))

instance_list		= compute.servers.all
instance_report	= Hash.new
tag_report			= Hash.new

# Flavor counts
instance_list.each do |i|
  if instance_report[i.flavor_id].nil?
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
#

# Tag counts
if !$aws_tags.empty?
  instance_list.each do |i|
  	$aws_tags.each do |tag|

  		# Make sure we have the intended tag
  		if !i.tags.nil? && !i.tags[tag].nil?

  			tag_value			= i.tags[tag]
  			formatted_tag = "tag_value" + $aws_tags_formatter
  			formatted_tag = eval(formatted_tag)

  			if tag_report[formatted_tag].nil?
  				tag_report[formatted_tag] = 1
  			else
  				tag_report[formatted_tag] = tag_report[formatted_tag] + 1
  			end

  		end
  	end
  end
end

tag_report.each do |tag, count|
  metricpath = "AWScountTags" + "." + tag.gsub(".","_")
  metricvalue = count
  metrictimestamp=Time.now.utc.to_i.to_s
  Sendit metricpath, metricvalue, metrictimestamp
end
#
