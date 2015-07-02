#!/usr/bin/env ruby
## grab AWS limits
### gem install fog  --no-ri --no-rdoc
### gem install aws-sdk --no-ri --no-rdoc

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
# require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'json'
require 'aws-sdk'
require 'optparse'

$options = {
    :start_offset => 180,
    :end_offset => 120
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: AWScloudwatchLimits.rb [options]"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    $options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.on('-h', '--help', '') do
    puts opts
    exit
  end
end

optparse.parse!

require 'Sendit'

startTime = Time.now.utc.to_i.to_s

creds = Aws::Credentials.new($awsaccesskey, $awssecretkey)
autoscaling_sdk = Aws::AutoScaling::Client.new(region:$awsregion, credentials:creds)
ec2_sdk = Aws::EC2::Client.new(region:$awsregion, credentials:creds)
autoscaling = Fog::AWS::AutoScaling.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)
compute = Fog::Compute.new(:provider => :aws, :aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)

account_limits = {}
asg_limits = autoscaling_sdk.describe_account_limits()
account_limits['autoscale_groups'] = asg_limits.data.max_number_of_auto_scaling_groups
account_limits['launch_configs'] = asg_limits.data.max_number_of_launch_configurations

ec2_limits = ec2_sdk.describe_account_attributes(attribute_names: ["max-instances","vpc-max-elastic-ips"])
ec2_limits.data.account_attributes.each do |ec2_limit|
  account_limits[ec2_limit.attribute_name.tr('-', '_').sub('max_', '')] = ec2_limit.attribute_values[0].attribute_value
end

account_values = {}
autoscalinggroup_list = autoscaling.groups.all
account_values['autoscale_groups'] = autoscalinggroup_list.length
autoscaling_launch_configs = autoscaling.configurations.all
account_values['launch_configs'] = autoscaling_launch_configs.length

vpc_eips = compute.addresses.all
account_values['vpc_elastic_ips'] = vpc_eips.length
current_instances = compute.servers.all
account_values['instances'] = current_instances.length

account_limits.each do |limit, value|
  metricpath = "AWSlimits." + limit + ".max"
  metricvalue = value
  metrictimestamp = startTime
  Sendit metricpath, metricvalue, metrictimestamp
end

account_values.each do |limit, value|
  metricpath = "AWSlimits." + limit + ".value"
  metricvalue = value
  metrictimestamp = startTime
  Sendit metricpath, metricvalue, metrictimestamp
end

exit 0
