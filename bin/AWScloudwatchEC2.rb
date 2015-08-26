#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
# require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'optparse'
require 'thread'

begin
  require 'system_timer'
  $SomeTimer = SystemTimer
rescue LoadError
  require 'timeout'
  $SomeTimer = Timeout
end

# Start back 15m by default
#  Instances with detailed monitoring will generally have 10+ metrics for this offset
#  Instances w/o detailed monitoring will only have 1-2
# 
# You probably don't want to go over 8 threads, unless AWS raises the rate limit on GetLogEvents > 10/sec
# http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/cloudwatch_limits.html
# Adjust for your environment
$options = {
    :start_offset => 900,
    :end_offset   => 0,
    :threads      => 4
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: AWScloudwatchEC2.rb [options]"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    $options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.on('-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 900 (15m)') do |s|
    $options[:start_offset] = s
  end

  opts.on('-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the end of the metrics period. Default 0 (now)') do |e|
    $options[:end_offset] = e
  end

  opts.on('-t', '--threads [NUMBER_OF_THREADS]', 'Number of threads to use for querying CloudWatch. Default 4') do |t|
    $options[:threads] = t
  end

  opts.on('-h', '--help', '') do
    puts opts
    exit
  end
end

optparse.parse!

# Moving this down so Sendit can use options
require 'Sendit'

$startTime = Time.now.utc - $options[:start_offset].to_i
$endTime   = Time.now.utc - $options[:end_offset].to_i
$runStart  = Time.now.utc
$metricsSent = 0
$collectionRetries = 0
$sendRetries = Hash.new(0)
my_script_tags = {}
my_script_tags[:script] = "AWScloudwatchEC2"
my_script_tags[:account] = "nonprod"

compute     = Fog::Compute.new( :provider => :aws,
              :region => $awsregion,
              :aws_access_key_id => $awsaccesskey,
              :aws_secret_access_key => $awssecretkey)
$cloudwatch  = Fog::AWS::CloudWatch.new(
              :region => $awsregion,
              :aws_access_key_id => $awsaccesskey,
              :aws_secret_access_key => $awssecretkey)

if ARGV.length > 0
  instance_list = [ compute.servers.get(ARGV[0]) ]
else
  instance_list = compute.servers.all
end

$metrics = [
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

def fetch_and_send(i)

  # Only fetch metrics if instance
  #  has a 'Name' tag and it isn't the instance id.

  # if i.tags.has_key?('Name') && !i.tags['Name'].start_with?('i-')
  if i.ready?
    retries = $cloudwatchretries
    responses = ''
    my_tags = i.tags
    my_tags.delete_if {|_, v| v.to_s.empty?}
    my_tags.each {|_, v| v.strip if v.is_a?(String)}
    my_tags.each {|_, v| v.tr(' ', '_') if v.is_a?(String)}
    my_tags[:instance_id] = i.id
    my_tags[:flavor_id] = i.flavor_id
    my_tags[:availability_zone] = i.availability_zone
    my_tags[:region] = i.availability_zone.chop

    $metrics.each do |metric|
      begin
        $SomeTimer.timeout($cloudwatchtimeout) do
          responses = $cloudwatch.get_metric_statistics({
                           'Statistics' => metric[:stat],
                           'StartTime'  => $startTime.iso8601,
                           'EndTime'    => $endTime.iso8601,
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
        $collectionRetries += 1
        puts "\tretries left: #{retries}"
        retry if retries > 0
      end

      responses.each do |response|
        # metricpath = "AWScloudwatch.EC2." + i.tags["Name"] + "." + metric[:name]
        metricpath = "AWScloudwatch.EC2." + i.id + "." + metric[:name]
        begin
          metricvalue     = response[metric[:stat]]
          metrictimestamp = response["Timestamp"].to_i.to_s
          Sendit metricpath, metricvalue, metrictimestamp, my_tags
          $metricsSent += 1
        rescue
          # ignored
        end
      end

    end

    # And send a counter, mostly useful for tagged backends
    metricpath = "AWScloudwatch.EC2." + i.id + ".count"
    Sendit metricpath, 1, $endTime.to_i.to_s, my_tags
    $metricsSent += 1

  end
end

work_q = Queue.new
instance_list.each{|i| work_q.push i}
workers = (0...$options[:threads].to_i).map do
  Thread.new do
    begin
      while i = work_q.pop(true)
        fetch_and_send(i)
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
