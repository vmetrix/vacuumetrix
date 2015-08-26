#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
# require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'json'
require 'optparse'

$options = {
    :start_offset => 1200,
    :end_offset => 600
}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScloudwatchDynamo.rb [options] table_names"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    $options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.on( '-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 1200') do |s|
    $options[:start_offset] = s
  end

  opts.on( '-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 600') do |e|
    $options[:end_offset] = e
  end

  opts.on( '-h', '--help', '' ) do
    puts opts
    exit
  end


end

optparse.parse!

require 'Sendit'

if ARGV.length == 0
  puts "Must specifiy at least one table name to pull metrics for"
  exit 1
end

tables = []
if ARGV.any? { |a| a.include?("*") }
  dynamo = Fog::AWS::DynamoDB.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)
  all_tables = []
  q = {}
  loop do
    resp = dynamo.list_tables(q)
    all_tables += resp.body['TableNames']
    break unless resp.body['LastEvaluatedTableName']
    q['ExclusiveStartTableName'] = resp.body['LastEvaluatedTableName']
  end
  ARGV.each do |pat|
    all_tables.each do |tab|
      tables << tab if File.fnmatch(pat, tab)
    end
  end
  tables.uniq!
else
  ARGV.each do |table|
    tables << table
  end
end

startTime = Time.now.utc - $options[:start_offset].to_i
endTime  = Time.now.utc - $options[:end_offset].to_i

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


cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)

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
