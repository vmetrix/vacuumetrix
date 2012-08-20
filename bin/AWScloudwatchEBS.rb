#!/usr/bin/env ruby
## EBS stats.  We don't really use much EBS, so I don't know if this is going to be very useful.  Feedback please!
### David Lutz
### 2012-07-19
### gem install fog  --no-ri --no-rdoc
$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems'
require 'fog'

#AWS cloudwatch stats for EBS seem to be at least 15 minutes behind and have a granualarity of 5 minutes

startTime = Time.now.utc-3600
endTime  = Time.now.utc-3300

compute = Fog::Compute.new(:provider => :aws, :aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)
instance_list = compute.volumes.all

# ['VolumeWriteBytes', 'VolumeWriteOps', 'VolumeReadBytes', 'VolumeIdleTime', 'VolumeTotalReadTime', 'VolumeQueueLength', 'VolumeTotalWriteTime', 'VolumeReadOps']
metricNames = ['VolumeWriteBytes', 'VolumeReadBytes']
statistic = 'Sum'
unit = 'Bytes'

instance_list.each do |i|
cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)
  
  metricNames.each do |metricName|
    response = cloudwatch.get_metric_statistics({
           'Statistics' => statistic,
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601,
           'Period'     => 300,
           'Unit'       => unit,
           'MetricName' => metricName,
           'Namespace'  => 'AWS/EBS',
           'Dimensions' => [{
                        'Name'  => 'VolumeId',
                        'Value' => i.id 
                        }]
           }).body['GetMetricStatisticsResult']['Datapoints']

  metricpath = "AWScloudwatch.EBS." + i.id + "." + metricName
  begin
        metricvalue = response.first[statistic]
  rescue
        metricvalue = 0
  end
  metrictimestamp = endTime.to_i.to_s

  Sendit metricpath, metricvalue, metrictimestamp
end
end



metricNames = ['VolumeWriteOps', 'VolumeQueueLength', 'VolumeReadOps']
statistic = 'Sum'
unit = 'Count'

instance_list.each do |i|
cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)
  
  metricNames.each do |metricName|
    response = cloudwatch.get_metric_statistics({
           'Statistics' => statistic,
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601,
           'Period'     => 300,
           'Unit'       => unit,
           'MetricName' => metricName,
           'Namespace'  => 'AWS/EBS',
           'Dimensions' => [{
                        'Name'  => 'VolumeId',
                        'Value' => i.id 
                        }]
           }).body['GetMetricStatisticsResult']['Datapoints']

  metricpath = "AWScloudwatch.EBS." + i.id + "." + metricName
  begin
        metricvalue = response.first[statistic]
  rescue
        metricvalue = 0
  end
  metrictimestamp = endTime.to_i.to_s

  Sendit metricpath, metricvalue, metrictimestamp
end
end

metricNames = ['VolumeIdleTime', 'VolumeTotalReadTime', 'VolumeTotalWriteTime', ]
statistic = 'Average'
unit = 'Seconds'

instance_list.each do |i|
cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)
  
  metricNames.each do |metricName|
    response = cloudwatch.get_metric_statistics({
           'Statistics' => statistic,
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601,
           'Period'     => 300,
           'Unit'       => unit,
           'MetricName' => metricName,
           'Namespace'  => 'AWS/EBS',
           'Dimensions' => [{
                        'Name'  => 'VolumeId',
                        'Value' => i.id 
                        }]
           }).body['GetMetricStatisticsResult']['Datapoints']

  metricpath = "AWScloudwatch.EBS." + i.id + "." + metricName
  begin
        metricvalue = response.first[statistic]
  rescue
        metricvalue = 0
  end
  metrictimestamp = endTime.to_i.to_s

  Sendit metricpath, metricvalue, metrictimestamp
end
end

