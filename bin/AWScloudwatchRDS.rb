#!/usr/bin/env ruby
## grab metrics from AWS cloudwatch
### David Lutz
### 2012-07-10
### gem install fog  --no-ri --no-rdoc
### if no argument is specified get metrics for all databases
### if a database name is specified as an argument then only show that database

### TODO: implement retry logic for collecting metrics

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
# require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'json'
require 'optparse'

$options = {
    :start_offset => 180,
    :end_offset => 120
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: AWScloudwatchRDS.rb [options] [DBInstanceIdentifier]"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    $options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.on('-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 1200') do |s|
    $options[:start_offset] = s
  end

  opts.on('-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 600') do |e|
    $options[:end_offset] = e
  end

  opts.on('-h', '--help', '') do
    puts opts
    exit
  end
end

optparse.parse!

require 'Sendit'

dbNames = []
if ARGV.length > 0
  ARGV.each do |db|
    dbNames << db
  end
else
  rds = Fog::AWS::RDS.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)
  rds.servers.all.each do |s|
    dbNames << s.id
  end
end

startTime = Time.now.utc - $options[:start_offset].to_i
endTime = Time.now.utc - $options[:end_offset].to_i

$runStart  = Time.now.utc
$metricsSent = 0
$collectionRetries = 0
$sendRetries = Hash.new(0)
my_script_tags = {}
my_script_tags[:script] = "AWScloudwatchRDS"
my_script_tags[:account] = "nonprod"

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


cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)

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
        $metricsSent += 1
      rescue
        # ignored
      end
    end
  end
end

$runEnd = Time.new.utc
$runDuration = $runEnd - $runStart

Sendit "vacuumetrix.#{my_script_tags[:script]}.run_time_sec", $runDuration, $runStart.to_i.to_s, my_script_tags
Sendit "vacuumetrix.#{my_script_tags[:script]}.metrics_sent", $metricsSent, $runStart.to_i.to_s, my_script_tags
Sendit "vacuumetrix.#{my_script_tags[:script]}.collection_retries", $collectionRetries, $runStart.to_i.to_s, my_script_tags
$sendRetries.each do |k, v|
  Sendit "vacuumetrics.#{my_script_tags[:script]}.send_retries_#{k.to_s}", v, $runStart.to_i.to_s, my_script_tags
end
