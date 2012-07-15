#!/usr/bin/env ruby
## grab metrics from AWS cloudwatch 
### David Lutz
### 2012-07-15
### gem install fog  --no-ri --no-rdoc
 
require 'rubygems'
require 'fog'
require 'json'
require '/opt/vacuumetrix/conf/config.rb'
require '/opt/vacuumetrix/lib/Sendit.rb'

if ARGV.length != 1
        puts "I need one argument. The ELB name"
        exit 1
end

dimensionId = ARGV[0]

#AWS cloudwatch stats seem to be a minute or so behind

startTime = Time.now.utc-180
endTime  = Time.now.utc-120


metricNames = {	"RequestCount"		=> "Sum",
		"HealthyHostCount" 	=> "Minimum", 
		"UnHealthyHostCount"	=> "Maximum",
		"HTTPCode_ELB_5XX"	=> "Sum",
		"HTTPCode_ELB_4XX"	=> "Sum",
		"HTTPCode_Backend_2XX"	=> "Sum",
		"HTTPCode_Backend_3XX"	=> "Sum",
		"HTTPCode_Backend_4XX"	=> "Sum",
		"HTTPCode_Backend_5XX"	=> "Sum"
	}

unit = 'Count'

cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)

metricNames.each do |metricName, statistic|
  response = cloudwatch.get_metric_statistics({
           'Statistics' => statistic, 
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601, 
	   'Period'     => 60, 
           'Unit'       => unit,
	   'MetricName' => metricName, 
	   'Namespace'  => 'AWS/ELB',
	   'Dimensions' => [{
	                'Name'  => 'LoadBalancerName', 
	                'Value' => dimensionId 
			}]
           }).body['GetMetricStatisticsResult']['Datapoints']

  metricpath = "AWScloudwatch.ELB." + dimensionId + "." + metricName 
  begin
  	metricvalue = response.first[statistic]
  rescue
	metricvalue = 0
  end
  metrictimestamp = endTime.to_i.to_s

  Sendit metricpath, metricvalue, metrictimestamp
end

#### also get latency (measured in seconds)

metricNames = { "Maximum"       => "Latency",
                "Average"       => "Latency",
        }

unit = 'Seconds'

cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)

metricNames.each do |statistic, metricName|
  response = cloudwatch.get_metric_statistics({
           'Statistics' => statistic,
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601,
           'Period'     => 60,
           'Unit'       => unit,
           'MetricName' => metricName,
           'Namespace'  => 'AWS/ELB',
           'Dimensions' => [{
                        'Name'  => 'LoadBalancerName',
                        'Value' => dimensionId
                        }]
           }).body['GetMetricStatisticsResult']['Datapoints']

  metricpath = "AWScloudwatch.ELB." + dimensionId + "." + metricName + "_" + statistic
  begin
        metricvalue = response.first[statistic]
  rescue
        metricvalue = 0
  end
  metrictimestamp = endTime.to_i.to_s

  Sendit metricpath, metricvalue, metrictimestamp
end

