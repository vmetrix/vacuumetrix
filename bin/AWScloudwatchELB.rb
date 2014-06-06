#!/usr/bin/env ruby
## grab metrics from AWS cloudwatch
### David Lutz
### 2012-07-15
### gem install fog  --no-ri --no-rdoc

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'json'
require 'optparse'

options = {
    :start_offset => 180,
    :end_offset => 120
}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScloudwatchELB.rb [options] lb_names"

  opts.on( '-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 180') do |s|
    options[:start_offset] = s
  end

  opts.on( '-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 120') do |e|
    options[:end_offset] = e
  end

  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', '' ) do
    puts opts
    exit
  end


end

optparse.parse!

if ARGV.length == 0
  puts "Must specifiy at least one load balancer name to pull metrics for"
  exit 1
end

lbs = []
ARGV.each do |lb|
  lbs << lb
end

startTime = Time.now.utc - options[:start_offset].to_i
endTime  = Time.now.utc - options[:end_offset].to_i


metricNames = {"RequestCount" => "Sum",
               "HealthyHostCount" => "Minimum",
               "UnHealthyHostCount" => "Maximum",
               "HTTPCode_ELB_5XX" => "Sum",
               "HTTPCode_ELB_4XX" => "Sum",
               "HTTPCode_Backend_2XX" => "Sum",
               "HTTPCode_Backend_3XX" => "Sum",
               "HTTPCode_Backend_4XX" => "Sum",
               "HTTPCode_Backend_5XX" => "Sum"
}

unit = 'Count'

cloudwatch = Fog::AWS::CloudWatch.new($awscredential.merge({:region => $awsregion}))

lbs.each do |table|
  metricNames.each do |metricName, statistic|
    responses = cloudwatch.get_metric_statistics({
                                                     'Statistics' => statistic,
                                                     'StartTime' => startTime.iso8601,
                                                     'EndTime' => endTime.iso8601,
                                                     'Period' => 60,
                                                     'Unit' => unit,
                                                     'MetricName' => metricName,
                                                     'Namespace' => 'AWS/ELB',
                                                     'Dimensions' => [{
                                                                          'Name' => 'LoadBalancerName',
                                                                          'Value' => table
                                                                      }]
                                                 }).body['GetMetricStatisticsResult']['Datapoints']

    responses.each do |response|
      metricpath = "AWScloudwatch.ELB." + table + "." + metricName
      begin
        metricvalue = response[statistic]
        metrictimestamp = response["Timestamp"].to_i.to_s
      rescue
        metricvalue = 0
        metrictimestamp = endTime.to_i.to_s
      end

      Sendit metricpath, metricvalue, metrictimestamp
    end
  end
end

#### also get latency (measured in seconds)

metricNames = {"Maximum" => "Latency",
               "Average" => "Latency",
}

unit = 'Seconds'

cloudwatch = Fog::AWS::CloudWatch.new($awscredential)

lbs.each do |table|
  metricNames.each do |statistic, metricName|
    responses = cloudwatch.get_metric_statistics({
                                                    'Statistics' => statistic,
                                                    'StartTime' => startTime.iso8601,
                                                    'EndTime' => endTime.iso8601,
                                                    'Period' => 60,
                                                    'Unit' => unit,
                                                    'MetricName' => metricName,
                                                    'Namespace' => 'AWS/ELB',
                                                    'Dimensions' => [{
                                                                         'Name' => 'LoadBalancerName',
                                                                         'Value' => table
                                                                     }]
                                                }).body['GetMetricStatisticsResult']['Datapoints']

    metricpath = "AWScloudwatch.ELB." + table + "." + metricName + "_" + statistic
    responses.each do |response|
      begin
        metricvalue = response[statistic]
        metrictimestamp = response["Timestamp"].to_i.to_s
      rescue
        metricvalue = 0
        metrictimestamp = endTime.to_i.to_s
      end

      Sendit metricpath, metricvalue, metrictimestamp
    end
  end
end
