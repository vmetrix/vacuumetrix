#!/usr/bin/env ruby
## Elasticache stats
### David Lutz
### 2012-08-01
### Updated on 2014-02-08 to add support for Redis engine
### Alejandro Ferrari (support@wmconsulting.info)

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'optparse'

options = {
    :start_offset => 180,
    :end_offset   => 120
}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScloudwatchElasticache.rb memcache/redis [options]"

  opts.on('-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 1200') do |s|
    options[:start_offset] = s
  end

  opts.on('-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 600') do |e|
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
  puts "Must specifiy at least one cache engine name to pull metrics for"
  exit 1
end

engine = ARGV[0]

startTime = Time.now.utc - options[:start_offset].to_i
endTime   = Time.now.utc - options[:end_offset].to_i

cw = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)
metrics_list = cw.list_metrics({
				'Namespace' => 'AWS/ElastiCache',
				'MetricName' => 'NetworkBytesIn'
		}).body['ListMetricsResult']['Metrics']


metrics_list.each do |met|
  next if met['Dimensions'].length==0

  cacheClusterId =  met['Dimensions'].first['Value']
  cacheNodeId = met['Dimensions'].last['Value']

  if engine == 'memcache'
    metricNames = ['GetMisses', 'GetHits', 'CurrConnections', 'CmdGet', 'CmdSet', 'CurrItems']
  end

  if engine == 'redis'
    metricNames = ['CacheMisses', 'CacheHits', 'CurrConnections', 'CurrItems', 'Evictions', 'Reclaimed', 'NewConnections']
  end

  statistic = 'Sum'
  unit = 'Count'

  metricNames.each do |metricName|
    response = cw.get_metric_statistics({
           'Statistics' => statistic,
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601,
           'Period'     => 60,
           'Unit'       => unit,
           'MetricName' => metricName,
           'Namespace'  => 'AWS/ElastiCache',
           'Dimensions' => met['Dimensions']
	           }).body['GetMetricStatisticsResult']['Datapoints']

    metricpath = "AWScloudwatch.Elasticache." + cacheClusterId + "." + metricName + "." + cacheNodeId
    begin
        metricvalue = response.first[statistic]
    rescue
        metricvalue = 0
    end
    metrictimestamp = endTime.to_i.to_s

    Sendit metricpath, metricvalue, metrictimestamp
  end
end



metrics_list.each do |met|
  next if met['Dimensions'].length==0

  cacheClusterId =  met['Dimensions'].first['Value']
  cacheNodeId = met['Dimensions'].last['Value']
  metricNames = ['CPUUtilization']
  statistic = 'Sum'
  unit = 'Percent'

  metricNames.each do |metricName|
    response = cw.get_metric_statistics({
           'Statistics' => statistic,
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601,
           'Period'     => 60,
           'Unit'       => unit,
           'MetricName' => metricName,
           'Namespace'  => 'AWS/ElastiCache',
           'Dimensions' => met['Dimensions']
	           }).body['GetMetricStatisticsResult']['Datapoints']

    metricpath = "AWScloudwatch.Elasticache." + cacheClusterId + "." + metricName + "." + cacheNodeId
    begin
        metricvalue = response.first[statistic]
    rescue
        metricvalue = 0
    end
    metrictimestamp = endTime.to_i.to_s

    Sendit metricpath, metricvalue, metrictimestamp
  end
end



metrics_list.each do |met|
  next if met['Dimensions'].length==0

  cacheClusterId =  met['Dimensions'].first['Value']
  cacheNodeId = met['Dimensions'].last['Value']

  if engine == 'memcache'
    metricNames = ['BytesReadIntoMemcached', 'BytesUsedForCacheItems', 'BytesWrittenOutFromMemcached']
  end
  if engine == 'redis'
    metricNames = ['BytesUsedForCache']
  end

  statistic = 'Sum'
  unit = 'Bytes'

  metricNames.each do |metricName|
    response = cw.get_metric_statistics({
           'Statistics' => statistic,
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601,
           'Period'     => 60,
           'Unit'       => unit,
           'MetricName' => metricName,
           'Namespace'  => 'AWS/ElastiCache',
           'Dimensions' => met['Dimensions']
	           }).body['GetMetricStatisticsResult']['Datapoints']

    metricpath = "AWScloudwatch.Elasticache." + cacheClusterId + "." + metricName + "." + cacheNodeId
    begin
        metricvalue = response.first[statistic]
    rescue
        metricvalue = 0
    end
    metrictimestamp = endTime.to_i.to_s

    Sendit metricpath, metricvalue, metrictimestamp
  end
end
