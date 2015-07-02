#!/usr/bin/env ruby
## Count how many of each type of EC2 instance we're running
## This works well as a stacked graph
### David Lutz
### 2012-07-16
### gem install fog  --no-ri --no-rdoc

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
# require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScountEC2.rb [options]"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    $options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.on( '-h', '--help', '' ) do
    puts opts
    exit
  end

end

optparse.parse!

require 'Sendit'

compute = Fog::Compute.new(	:provider => :aws,
							:region => $awsregion,
							:aws_access_key_id => $awsaccesskey,
							:aws_secret_access_key => $awssecretkey)

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
  			formatted_tag_value = "tag_value" + $aws_tags_formatter
  			formatted_tag_value = eval(formatted_tag_value)
        formatted_tag_value = formatted_tag_value.gsub(".","_")
        tag_plus_value = "#{tag}.#{formatted_tag_value}"

  			if tag_report[tag_plus_value].nil?
  				tag_report[tag_plus_value] = 1
  			else
  				tag_report[tag_plus_value] = tag_report[tag_plus_value] + 1
  			end

  		end
  	end
  end
end

tag_report.each do |tag, count|
  ## metricpath = "AWScountTags" + "." + tag.gsub(".","_")
  metricpath = "AWScountTags" + "." + tag
  metricvalue = count
  metrictimestamp=Time.now.utc.to_i.to_s
  Sendit metricpath, metricvalue, metrictimestamp
end
#
