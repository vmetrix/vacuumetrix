#!/usr/bin/env ruby
## grab custom metrics from AWS cloudwatch
### based on scripts by:
### David Lutz
### 2012-07-15
### gem install fog  --no-ri --no-rdoc

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
# require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'json'
require 'optparse'
require 'thread'

begin
  require 'system_timer'
rescue LoadError
  require 'timeout'
  SomeTimer = Timeout
end

$options = {
    :namespaces_age => 7200,
    :namespaces_file => '/tmp/vacuumetrix-namespaces-cache',
    :start_offset => 300,
    :end_offset => 0,
    :threads => 1
}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScloudwatchCustom.rb [options]"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    $options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

### For now, default to collect all custom metrics, future versions of this script
### could allow for passing a list of Namespaces on the commandline to filter on
#  opts.on( '-a', '--all', 'Collect all custom metrics') do
#    $options[:all] = true
#  end

  opts.on( '-n', '--namespaces_age [SECONDS]', 'Max age of cached list of Namespaces in seconds. Default 7200') do |age|
    $options[:namespaces_age] = age
  end

  opts.on( '-N', '--namespaces_file [PATH]', 'Full path to tempfile for list of Namespaces. Default /tmp/vacuumetrix-namespaces-cache') do |file|
    $options[:namespaces_file] = file
  end

  opts.on( '-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 300') do |s|
    $options[:start_offset] = s
  end

  opts.on( '-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 0') do |e|
    $options[:end_offset] = e
  end

  opts.on('-t', '--threads [NUMBER_OF_THREADS]', 'Number of threads to use for querying CloudWatch. Default 1') do |t|
    $options[:threads] = t
  end

  opts.on( '-h', '--help', '' ) do
    puts opts
    exit
  end

end

optparse.parse!

require 'Sendit'

$cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)
$namespaces = []
$custom_metrics = []

###

def list_metrics_batch(run_number, next_token = '', namespace = nil)
  if run_number == 0
    if namespace
      get_metrics = $cloudwatch.list_metrics({'Namespace' => namespace}).body['ListMetricsResult']
    else
      get_metrics = $cloudwatch.list_metrics().body['ListMetricsResult']
    end
  else
    if namespace
      get_metrics = $cloudwatch.list_metrics({'NextToken' => next_token, 'Namespace' => namespace}).body['ListMetricsResult']
    else
      get_metrics = $cloudwatch.list_metrics({'NextToken' => next_token}).body['ListMetricsResult']
    end
  end
  metrics = get_metrics['Metrics']
  next_token = get_metrics['NextToken']
  i = 0
  metrics.each do |metric|
    unless metric['Namespace'] =~ /AWS\//
      i += 1
      $custom_metrics << metric
    end
  end
  return next_token
end

def list_metrics(namespace)
  run_number = 0
  next_token = ''

  while next_token do
    next_token = list_metrics_batch(run_number, next_token, namespace)
    run_number += 1
  end
end

def update_namespace_cache(namespaces_file)
  $namespaces = $custom_metrics.map { |metric| metric['Namespace'] }.uniq

  File.open(namespaces_file, 'w') do |f|
    f.write($namespaces.to_json)
  end
end

def read_namespace_cache(namespaces_file)
  buffer = File.read(namespaces_file)
  $namespaces = JSON.parse(buffer)
end

$startTime = Time.now.utc - $options[:start_offset].to_i
$endTime  = Time.now.utc - $options[:end_offset].to_i

$runStart  = Time.now.utc
$metricsSent = 0
$collectionRetries = 0
$sendRetries = Hash.new(0)
my_script_tags = {}
my_script_tags[:script] = "AWScloudwatchCustom"
my_script_tags[:account] = "nonprod"

if File.exists?($options[:namespaces_file])
  cache_age = Time.now - File.mtime($options[:namespaces_file])
  if cache_age > $options[:namespaces_age].to_i
    list_metrics(false)
    update_namespace_cache($options[:namespaces_file])
  else
    read_namespace_cache($options[:namespaces_file])
    $namespaces.each do |namespace|
      list_metrics(namespace)
    end
  end
else
  # if no cache file, create and populate it
  list_metrics(false)
  update_namespace_cache($options[:namespaces_file])
end

def fetch_and_send(metric)
  retries = $cloudwatchretries
  responses = ''
  begin
    SomeTimer.timeout($cloudwatchtimeout) do
      responses = $cloudwatch.get_metric_statistics({
                                                   'Statistics' => 'Average',
                                                   'StartTime' => $startTime.iso8601,
                                                   'EndTime' => $endTime.iso8601,
                                                   'Period' => 60,
                                                   'MetricName' => metric['MetricName'],
                                                   'Namespace' => metric['Namespace'],
                                                   'Dimensions' => metric['Dimensions']
                                               }).body['GetMetricStatisticsResult']['Datapoints']
      end
    rescue => e
      puts "error fetching metric :: " + metric['MetricName'] + " :: " 
      puts "\terror: #{e}"
      retries -= 1
      $collectionRetries += 1
      puts "\tretries left: #{retries}"
      retry if retries > 0
    end

    responses.each do |response|
      dimensions_string = ''
      dimensions_string = metric['Dimensions'].map { |dimension| "#{dimension['Name']}=#{dimension['Value']}" }.join "."
      metricpath = "AWScloudwatch.custom.#{metric['Namespace']}#{'.' + dimensions_string unless dimensions_string == ''}.#{metric['MetricName']}.#{response['Unit']}"
      begin
        metricvalue = response['Average']
        metrictimestamp = response["Timestamp"].to_i.to_s
      rescue
        metricvalue = 0
        metrictimestamp = $endTime.to_i.to_s
      end

      Sendit metricpath, metricvalue, metrictimestamp
      $metricsSent += 1
    end
end

work_q = Queue.new
$custom_metrics.each{|custom_metric| work_q.push custom_metric}
workers = (0...$options[:threads].to_i).map do
  Thread.new do
    begin
      while custom_metric = work_q.pop(true)
        fetch_and_send(custom_metric)
      end
    rescue ThreadError
    end
  end
end; "ok"
workers.map(&:join); "ok"

runEnd = Time.new.utc
$runDuration = $runEnd - $runStart

Sendit "vacuumetrix.#{my_script_tags[:script]}.run_time_sec", $runDuration, $runStart.to_i.to_s, my_script_tags
Sendit "vacuumetrix.#{my_script_tags[:script]}.metrics_sent", $metricsSent, $runStart.to_i.to_s, my_script_tags
Sendit "vacuumetrix.#{my_script_tags[:script]}.collection_retries", $collectionRetries, $runStart.to_i.to_s, my_script_tags
$sendRetries.each do |k, v|
  Sendit "vacuumetrics.#{my_script_tags[:script]}.send_retries_#{k.to_s}", v, $runStart.to_i.to_s, my_script_tags
end
