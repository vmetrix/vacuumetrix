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
    :start_offset => 21660,
    :end_offset => 60
}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: AWScloudwatchBilling.rb [options]"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    $options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.on( '-s', '--start-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 21660') do |s|
    $options[:start_offset] = s
  end

  opts.on( '-e', '--end-offset [OFFSET_SECONDS]', 'Time in seconds to offset from current time as the start of the metrics period. Default 60') do |e|
    $options[:end_offset] = e
  end

  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', '' ) do
    puts opts
    exit
  end
end

optparse.parse!

require 'Sendit'

startTime = Time.now.utc - $options[:start_offset].to_i
endTime  = Time.now.utc - $options[:end_offset].to_i

$runStart  = Time.now.utc
$metricsSent = 0
$collectionRetries = 0
$sendRetries = Hash.new(0)
my_script_tags = {}
my_script_tags[:script] = "AWScloudwatchBilling"
my_script_tags[:account] = "nonprod"

cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)

# Query for all existing Billing Metrics in CloudWatch, this should catch new services as they are added
billing_services = []
billing_metrics = cloudwatch.list_metrics({'Namespace' => "AWS/Billing", 'Dimensions' => [{'Name' => "ServiceName"}]})
metrics = billing_metrics[:body]['ListMetricsResult']['Metrics']
metrics.each do |metric|
  metric['Dimensions'].each do |dimension|
    if dimension['Name'] == "ServiceName"
      billing_services << dimension['Value']
    end
  end
end

billing_services.each do |name|
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
      $metricsSent += 1
    rescue
      # Ignored
    end
  end
end

$runEnd = Time.new.utc
$runDuration = $runEnd - $runStart

Sendit "vacuumetrix.#{my_script_tags[:script]}.run_time_sec", $runDuration, $runStart.to_i.to_s, my_script_tags
Sendit "vacuumetrix.#{my_script_tags[:script]}.metrics_sent", $metricsSent, $runStart.to_i.to_s, my_script_tags
Sendit "vacuumetrix.#{my_script_tags[:script]}.collection_retries", $collectionRetries, $runStart.to_i.to_s, my_script_tags
$sendRetries.each do |k, v|
  Sendit "vacuumetrix.#{my_script_tags[:script]}.send_retries_#{k.to_s}", v, $runStart.to_i.to_s, my_script_tags
end
