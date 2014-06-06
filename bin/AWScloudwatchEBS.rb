#!/usr/bin/env ruby
## EBS stats.  We don't really use much EBS, so I don't know if this is going to be very useful.  Feedback please!
### David Lutz
### 2012-07-19
### gem install fog  --no-ri --no-rdoc
$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'fog'
require 'optparse'

#AWS cloudwatch stats for EBS seem to be at least 15 minutes behind and have a granualarity of 5 minutes
options = {
    :start_offset => 3600,
    :end_offset   => 3300
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: AWScloudwatchEBS.rb [options] [VolumeIds]"

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


startTime = Time.now.utc - options[:start_offset].to_i
endTime   = Time.now.utc - options[:end_offset].to_i

volumeIds = []
if ARGV.length > 0
  ARGV.each do |vol|
    volumeIds << vol
  end
else
  compute = Fog::Compute.new($awscredential.merge({:provider => :aws}))
  compute.volumes.all.each do |vol|
    volumeIds << vol.id
  end
end

metrics = [
    {
        :name => "VolumeWriteBytes",
        :unit => "Bytes",
        :stat => "Sum"
    },
    {
        :name => "VolumeReadBytes",
        :unit => "Bytes",
        :stat => "Sum"
    },
    {
        :name => "VolumeWriteOps",
        :unit => "Count",
        :stat => "Sum"
    },
    {
        :name => "VolumeReadOps",
        :unit => "Count",
        :stat => "Sum"
    },
    {
        :name => "VolumeTotalReadTime",
        :unit => "Seconds",
        :stat => "Sum"
    },
    {
        :name => "VolumeTotalWriteTime",
        :unit => "Seconds",
        :stat => "Sum"
    },
    {
        :name => "VolumeIdleTime",
        :unit => "Seconds",
        :stat => "Sum"
    },
    {
        :name => "VolumeQueueLength",
        :unit => "Count",
        :stat => "Sum"
    },
    {
        :name => "VolumeThroughputPercentage",
        :unit => "Percent",
        :stat => "Average"
    },
    {
        :name => "VolumeConsumedReadWriteOps",
        :unit => "Count",
        :stat => "Sum"
    }
]

cloudwatch = Fog::AWS::CloudWatch.new($awscredential)

volumeIds.each do |volume|
  metrics.each do |metric|
    responses = cloudwatch.get_metric_statistics({
                                                     'Statistics' => metric[:stat],
                                                     'StartTime'  => startTime.iso8601,
                                                     'EndTime'    => endTime.iso8601,
                                                     'Period'     => 300,
                                                     'Unit'       => metric[:unit],
                                                     'MetricName' => metric[:name],
                                                     'Namespace'  => 'AWS/EBS',
                                                     'Dimensions' => [{
                                                                          'Name'  => 'VolumeId',
                                                                          'Value' => volume
                                                                      }]
                                                 }).body['GetMetricStatisticsResult']['Datapoints']

    responses.each do |response|
      metricpath = "AWScloudwatch.EBS." + volume + "." + metric[:name]
      begin
        metricvalue     = response[metric[:stat]]
        metrictimestamp = response["Timestamp"].to_i.to_s

        Sendit metricpath, metricvalue, metrictimestamp
      rescue
        # ignored
      end
    end
  end
end
