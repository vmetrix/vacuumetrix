#!/usr/bin/env ruby
## grab metrics from AWS cloudwatch
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
    :start_offset => 180,
    :end_offset => 120,
    :threads => 1
}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScloudwatchELB.rb [options] [--all|lb_names]"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    $options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.on( '-a', '--all', 'Collect metrics for all ELBs') do
    $options[:all] = true
  end

  opts.on( '-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 180') do |s|
    $options[:start_offset] = s
  end

  opts.on( '-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 120') do |e|
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

elb = Fog::AWS::ELB.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)
$cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)

lbs = []
if $options[:all]
  my_lb_list = elb.load_balancers.all
  my_lb_list.each do |my_lb|
    lbs << my_lb.id
  end
elsif ARGV.length == 0
  puts "Must specifiy at least one load balancer name to pull metrics for"
  exit 1
else
  ARGV.each do |lb|
    lbs << lb
  end
end

$startTime = Time.now.utc - $options[:start_offset].to_i
$endTime  = Time.now.utc - $options[:end_offset].to_i

$runStart  = Time.now.utc
$metricsSent = 0
$collectionRetries = 0
$sendRetries = Hash.new(0)
my_script_tags = {}
my_script_tags[:script] = "AWScloudwatchELB"
my_script_tags[:account] = "nonprod"

$metricNames = {"RequestCount" => ["Sum"],
               "HealthyHostCount" => ["Minimum"],
               "UnHealthyHostCount" => ["Maximum"],
               "HTTPCode_ELB_5XX" => ["Sum"],
               "HTTPCode_ELB_4XX" => ["Sum"],
               "HTTPCode_Backend_2XX" => ["Sum"],
               "HTTPCode_Backend_3XX" => ["Sum"],
               "HTTPCode_Backend_4XX" => ["Sum"],
               "HTTPCode_Backend_5XX" => ["Sum"],
               "Latency" => ["Maximum", "Average"]
}

def fetch_and_send(lb)
  retries = $cloudwatchretries
  responses = ''
  $metricNames.each do |metricName, statistics|
    unit = metricName == "Latency" ? 'Seconds' : 'Count'
    statistics.each do |statistic|
    begin
      SomeTimer.timeout($cloudwatchtimeout) do
        responses = $cloudwatch.get_metric_statistics({
                                                     'Statistics' => statistic,
                                                     'StartTime' => $startTime.iso8601,
                                                     'EndTime' => $endTime.iso8601,
                                                     'Period' => 60,
                                                     'Unit' => unit,
                                                     'MetricName' => metricName,
                                                     'Namespace' => 'AWS/ELB',
                                                     'Dimensions' => [{
                                                                          'Name' => 'LoadBalancerName',
                                                                          'Value' => lb
                                                                      }]
                                                 }).body['GetMetricStatisticsResult']['Datapoints']
        end
      rescue => e
        puts "error fetching metric :: " + metricName + " :: " + lb
        puts "\terror: #{e}"
        retries -= 1
        $collectionRetries += 1
        puts "\tretries left: #{retries}"
        retry if retries > 0
      end

      responses.each do |response|
        metricpath = "AWScloudwatch.ELB." + lb + "." + metricName
        metricpath += "_#{statistic}" if metricName == 'Latency'
        begin
          metricvalue = response[statistic]
          metrictimestamp = response["Timestamp"].to_i.to_s
        rescue
          metricvalue = 0
          metrictimestamp = endTime.to_i.to_s
        end

        Sendit metricpath, metricvalue, metrictimestamp
        $metricsSent += 1
      end
    end
  end
end

work_q = Queue.new
lbs.each{|lb| work_q.push lb}
workers = (0...$options[:threads].to_i).map do
  Thread.new do
    begin
      while lb = work_q.pop(true)
        fetch_and_send(lb)
      end
    rescue ThreadError
    end
  end
end; "ok"
workers.map(&:join); "ok"

$runEnd = Time.new.utc
$runDuration = $runEnd - $runStart

Sendit "vacuumetrix.#{my_script_tags[:script]}.run_time_sec", $runDuration, $runStart.to_i.to_s, my_script_tags
Sendit "vacuumetrix.#{my_script_tags[:script]}.metrics_sent", $metricsSent, $runStart.to_i.to_s, my_script_tags
Sendit "vacuumetrix.#{my_script_tags[:script]}.collection_retries", $collectionRetries, $runStart.to_i.to_s, my_script_tags
$sendRetries.each do |k, v|
  Sendit "vacuumetrix.#{my_script_tags[:script]}.send_retries_#{k.to_s}", v, $runStart.to_i.to_s, my_script_tags
end
