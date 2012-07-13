#!/usr/bin/env ruby
## grab metrics from AWS cloudwatch 
### David Lutz
### 2012-07-10
### gem install fog  --no-ri --no-rdoc
 
require 'rubygems'
require 'fog'
require 'json'
require '/opt/vacuumetrix/conf/config.rb'
require '/opt/vacuumetrix/lib/Sendit.rb'

if ARGV.length != 1
        puts "I need one argument. The RDS instance name"
        exit 1
end

dimensionId = ARGV[0]

#AWS cloudwatch stats seem to be a minute or so behind

startTime = (Time.now.gmtime-180).iso8601
endTime  = (Time.now.gmtime-120).iso8601

t=Time.now.utc
timenow=t.to_i

unit           = 'Percent'
statisticTypes = 'Average'

cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)

metricName     = 'CPUUtilization'

response = cloudwatch.get_metric_statistics({
           'Statistics' => 'Average',
           'StartTime' =>  startTime,
           'EndTime'    => endTime, 
	   'Period'     => 60, 
           'Unit'       => unit,
	   'MetricName' => metricName, 
	   'Namespace'  => 'AWS/RDS',
	   'Dimensions' => [{
	                'Name'  => 'DBInstanceIdentifier', 
	                'Value' => dimensionId 
			}]
           }).body['GetMetricStatisticsResult']['Datapoints']

metricpath = "AWScloudwatch.RDS." + dimensionId + "." + metricName 
metricvalue = response.first["Average"]
metrictimestamp = timenow.to_s

Sendit metricpath, metricvalue, metrictimestamp
