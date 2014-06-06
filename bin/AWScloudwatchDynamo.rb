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
    :start_offset => 1200,
    :end_offset => 600
}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScloudwatchDynamo.rb [options] table_names"

  opts.on( '-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 1200') do |s|
    options[:start_offset] = s
  end

  opts.on( '-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 600') do |e|
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
  puts "Must specifiy at least one table name to pull metrics for"
  exit 1
end

tables = []
ARGV.each do |table|
  tables << table
end

startTime = Time.now.utc - options[:start_offset].to_i
endTime  = Time.now.utc - options[:end_offset].to_i

operations = %w(PutItem DeleteItem UpdateItem GetItem BatchGetItem Scan Query)
operationLevelMetrics = [
    {
        :name => "SuccessfulRequestLatency",
        :unit => "Milliseconds",
        :stats => ["Minimum", "Maximum", "Average"]
    },
    {
        :name => "ThrottledRequests",
        :unit => "Count",
        :stats => ["Sum"],
    },
    {
        :name => "SystemErrors",
        :unit => "Count",
        :stats => ["Sum"],
    },
    {
        :name => "UserErrors",
        :unit => "Count",
        :stats => ["Sum"],
    },
    {
        :name => "ReturnedItemCount",
        :unit => "Count",
        :stats => ["Minimum", "Maximum", "Average", "Sum"],
    }
]


cloudwatch = Fog::AWS::CloudWatch.new($awscredential)

tables.each do |table|
  operationLevelMetrics.each do |metric|
    operations.each do |operation|
      responses = cloudwatch.get_metric_statistics({
                                                         'Statistics' => metric[:stats],
                                                         'StartTime' => startTime.iso8601,
                                                         'EndTime' => endTime.iso8601,
                                                         'Period' => 300,
                                                         'Unit' => metric[:unit],
                                                         'MetricName' => metric[:name],
                                                         'Namespace' => 'AWS/DynamoDB',
                                                         'Dimensions' => [
                                                             {
                                                                 'Name' => 'TableName',
                                                                 'Value' => table
                                                             },
                                                             {
                                                                 'Name' => "Operation",
                                                                 'Value' => operation
                                                             }
                                                         ]
                                                     }).body['GetMetricStatisticsResult']['Datapoints']

      metric[:stats].each do |stat|
        responses.each do |response|
          metricpath = "AWScloudwatch.Dynamo." + table + "." + metric[:name] + "." + operation + "." + stat
          begin
            metricvalue = response[stat]
            metrictimestamp = response["Timestamp"].to_i.to_s

            Sendit metricpath, metricvalue, metrictimestamp
          rescue
            # ignored
          end
        end
      end
    end
  end
end

tableLevelMetrics = [
    {
        :name => "SystemErrors",
        :unit => "Count",
        :stats => ["Sum"],
    },
    {
        :name => "ProvisionedReadCapacityUnits",
        :unit => "Count",
        :stats => ["Average"],
    },
    {
        :name => "ProvisionedWriteCapacityUnits",
        :unit => "Count",
        :stats => ["Average"],
    },
    {
        :name => "ConsumedReadCapacityUnits",
        :unit => "Count",
        :stats => ["Minimum", "Maximum", "Average", "Sum"],
    },
    {
        :name => "ConsumedWriteCapacityUnits",
        :unit => "Count",
        :stats => ["Minimum", "Maximum", "Average", "Sum"],
    }
]

tables.each do |table|
  tableLevelMetrics.each do |metric|
    responses = cloudwatch.get_metric_statistics({
                                                       'Statistics' => metric[:stats],
                                                       'StartTime' => startTime.iso8601,
                                                       'EndTime' => endTime.iso8601,
                                                       'Period' => 300,
                                                       'Unit' => metric[:unit],
                                                       'MetricName' => metric[:name],
                                                       'Namespace' => 'AWS/DynamoDB',
                                                       'Dimensions' => [{
                                                                            'Name' => 'TableName',
                                                                            'Value' => table
                                                                        }]
                                                   }).body['GetMetricStatisticsResult']['Datapoints']

    metric[:stats].each do |stat|
      responses.each do |response|
        metricpath = "AWScloudwatch.Dynamo." + table + "." + metric[:name] + "." + stat
        begin
          metricvalue = response[stat]
          metrictimestamp = response["Timestamp"].to_i.to_s

          Sendit metricpath, metricvalue, metrictimestamp
        rescue
          # Ignored
        end
      end
    end
  end
end
