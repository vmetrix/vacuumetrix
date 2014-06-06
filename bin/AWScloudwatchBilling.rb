#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'json'
require 'optparse'

options = {
    :start_offset => 21660,
    :end_offset => 60
}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScloudwatchBilling.rb [options]"

  opts.on( '-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 21660') do |s|
    options[:start_offset] = s
  end

  opts.on( '-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 60') do |e|
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

startTime = Time.now.utc - options[:start_offset].to_i
endTime  = Time.now.utc - options[:end_offset].to_i


cloudwatch = Fog::AWS::CloudWatch.new($awscredential)

%w( AmazonCloudFront AmazonDynamoDB AmazonEC2 AmazonRDS AmazonS3 AmazonSNS AWSDataTransfer ).each do |name|
  responses = cloudwatch.get_metric_statistics({
                                                   'Statistics' => "Maximum",
                                                   'StartTime' => startTime.iso8601,
                                                   'EndTime' => endTime.iso8601,
                                                   'Period' => 3600,
                                                   'Unit' => "None",
                                                   'MetricName' => "EstimatedCharges",
                                                   'Namespace' => "AWS/Billing",
                                                   'Dimensions' => [
                                                       {
                                                           'Name' => "ServiceName",
                                                           'Value' => name
                                                       },
                                                       {
                                                           'Name' => "Currency",
                                                           'Value' => "USD"
                                                       }
                                                   ]
                                               }).body['GetMetricStatisticsResult']['Datapoints']

  responses.each do |response|
    begin
      metricpath = "AWScloudwatch.Billing." + name
      metricvalue = response["Maximum"]
      metrictimestamp = response["Timestamp"].to_i.to_s

      Sendit metricpath, metricvalue, metrictimestamp
    rescue
      # Ignored
    end
  end
end
