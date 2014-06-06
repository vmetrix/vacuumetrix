#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'optparse'

begin
  require 'system_timer'
  SomeTimer = SystemTimer
rescue LoadError
  require 'timeout'
  SomeTimer = Timeout
end

# Start back 15m by default
#  Instances with detailed monitoring will generally have 10+ metrics for this offset
#  Instances w/o detailed monitoring will only have 1-2
# Adjust for your environment
options = {
    :start_offset => 900,
    :end_offset   => 0
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: AWScloudwatchEC2.rb [options]"

  opts.on('-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 900 (15m)') do |s|
    options[:start_offset] = s
  end

  opts.on('-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the end of the metrics period. Default 0 (now)') do |e|
    options[:end_offset] = e
  end

  opts.on('-h', '--help', '') do
    puts opts
    exit
  end
end

optparse.parse!

startTime = Time.now.utc - options[:start_offset].to_i
endTime   = Time.now.utc - options[:end_offset].to_i

compute     = Fog::Compute.new($awscredential.merge({:provider => :aws}))
cloudwatch  = Fog::AWS::CloudWatch.new($awscredential)

instance_list = compute.servers.all

metrics = [
    {
        :name => "CPUUtilization",
        :unit => "Percent",
        :stat => "Average"
    },
    {
        :name => "DiskReadBytes",
        :unit => "Bytes",
        :stat => "Average"
    },
    {
        :name => "DiskReadOps",
        :unit => "Count",
        :stat => "Average"
    },
    {
        :name => "DiskWriteBytes",
        :unit => "Bytes",
        :stat => "Average"
    },
    {
        :name => "DiskWriteOps",
        :unit => "Count",
        :stat => "Average"
    },
    {
        :name => "NetworkIn",
        :unit => "Bytes",
        :stat => "Average"
    },
    {
        :name => "NetworkOut",
        :unit => "Bytes",
        :stat => "Average"
    }
]

instance_list.each do |i|

  # Only fetch metrics if instance
  #  has a 'Name' tag and it isn't the instance id.

  if i.tags.has_key?('Name') && !i.tags['Name'].start_with?('i-')
    retries = $cloudwatchretries
    responses = ''
    metrics.each do |metric|
      begin
        SomeTimer.timeout($cloudwatchtimeout) do
          responses = cloudwatch.get_metric_statistics({
                           'Statistics' => metric[:stat],
                           'StartTime'  => startTime.iso8601,
                           'EndTime'    => endTime.iso8601,
                           'Period'     => 60,
                           'Unit'       => metric[:unit],
                           'MetricName' => metric[:name],
                           'Namespace'  => 'AWS/EC2',
                           'Dimensions' => [{
                                                'Name'  => 'InstanceId',
                                                'Value' => i.id
                                            }]
                       }).body['GetMetricStatisticsResult']['Datapoints']
        end
      rescue => e
        puts "error fetching metric :: " + metric[:name] + " :: " + i.id
        puts "\terror: #{e}"
        retries -= 1
        puts "\tretries left: #{retries}"
        retry if retries > 0
      end

      responses.each do |response|
        metricpath = "AWScloudwatch.EC2." + i.tags["Name"] + "." + metric[:name]
        begin
          metricvalue     = response[metric[:stat]]
          metrictimestamp = response["Timestamp"].to_i.to_s
          Sendit metricpath, metricvalue, metrictimestamp
        rescue
          # ignored
        end
      end

    end

  end
end
