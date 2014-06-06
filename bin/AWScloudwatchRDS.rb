#!/usr/bin/env ruby
## grab metrics from AWS cloudwatch
### David Lutz
### 2012-07-10
### gem install fog  --no-ri --no-rdoc
### if no argument is specified get metrics for all databases
### if a database name is specified as an argument then only show that database

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

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: AWScloudwatchRDS.rb [options] [DBInstanceIdentifier]"

  opts.on('-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 1200') do |s|
    options[:start_offset] = s
  end

  opts.on('-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 600') do |e|
    options[:end_offset] = e
  end

  opts.on('-h', '--help', '') do
    puts opts
    exit
  end
end

optparse.parse!

dbNames = []
if ARGV.length > 0
  ARGV.each do |db|
    dbNames << db
  end
else
  rds = Fog::AWS::RDS.new($awscredential)
  rds.servers.all.each do |s|
    dbNames << s.id
  end
end

startTime = Time.now.utc - options[:start_offset].to_i
endTime = Time.now.utc - options[:end_offset].to_i

metricNames = {"CPUUtilization" => "Percent",
               "DatabaseConnections" => "Count",
               "FreeStorageSpace" => "Bytes",
               "ReadIOPS" => "Count/Second",
               "ReadLatency" => "Seconds",
               "ReadThroughput" => "Bytes/Second",
               "WriteIOPS" => "Count/Second",
               "WriteLatency" => "Seconds",
               "WriteThroughput" => "Bytes/Second",
               "ReplicaLag" => "Seconds",
               "SwapUsage" => "Bytes",
               "BinLogDiskUsage" => "Bytes",
               "DiskQueueDepth" => "Count",
}


cloudwatch = Fog::AWS::CloudWatch.new($awscredential)

dbNames.each do |db|
  metricNames.each do |metricName, unit|
    responses = cloudwatch.get_metric_statistics({
                                                     'Statistics' => 'Average',
                                                     'StartTime' => startTime.iso8601,
                                                     'EndTime' => endTime.iso8601,
                                                     'Period' => 60,
                                                     'Unit' => unit,
                                                     'MetricName' => metricName,
                                                     'Namespace' => 'AWS/RDS',
                                                     'Dimensions' => [{
                                                                          'Name' => 'DBInstanceIdentifier',
                                                                          'Value' => db
                                                                      }]
                                                 }).body['GetMetricStatisticsResult']['Datapoints']

    responses.each do |response|
      metricpath = "AWScloudwatch.RDS." + db + "." + metricName
      begin
        metricvalue = response["Average"]
        metrictimestamp = response["Timestamp"].to_i.to_s
        Sendit metricpath, metricvalue, metrictimestamp
      rescue
        # ignored
      end
    end
  end
end
