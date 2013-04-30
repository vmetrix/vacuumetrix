#!/usr/bin/env ruby
## grab metrics from AWS cloudwatch 
### David Lutz
### 2012-07-10
### gem install fog  --no-ri --no-rdoc
### if no argument is specified get metrics for all databases
### if a database name is specified as an argument then only show that database
 
$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems'
require 'fog'
require 'json'

if ARGV.length == 1
  dimensionId = ARGV[0]
end

#AWS cloudwatch stats seem to be a minute or so behind

startTime = Time.now.utc-180
endTime  = Time.now.utc-120

metricNames = {	"CPUUtilization" 	=> "Percent", 
		"DatabaseConnections" 	=> "Count",
		"FreeStorageSpace" 	=> "Bytes",
		"ReadIOPS"		=> "Count/Second",
 		"ReadLatency"		=> "Seconds",
		"ReadThroughput"	=> "Bytes/Second",
		"WriteIOPS"		=> "Count/Second",
 		"WriteLatency"		=> "Seconds",
		"WriteThroughput"	=> "Bytes/Second",
		"ReplicaLag"		=> "Seconds",
	}

statisticTypes = 'Average'

rds = Fog::AWS::RDS.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey, :region => $awsregion)

if !dimensionId.nil?
  instance_list = rds.servers.get(dimensionId)
  cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)

  metricNames.each do |metricName, unit|
    begin
      response = cloudwatch.get_metric_statistics({
           'Statistics' => 'Average',
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601, 
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
      metrictimestamp = endTime.to_i.to_s

      Sendit metricpath, metricvalue, metrictimestamp
    rescue
# silently catch error when there's no ReplicaLag metric
    end
  end
  else
    instance_list = rds.servers.all

    instance_list.each do |i|
    cloudwatch = Fog::AWS::CloudWatch.new(:aws_secret_access_key => $awssecretkey, :aws_access_key_id => $awsaccesskey)

    dimensionId = i.id
    metricNames.each do |metricName, unit|
      begin
        response = cloudwatch.get_metric_statistics({
           'Statistics' => 'Average',
           'StartTime' =>  startTime.iso8601,
           'EndTime'    => endTime.iso8601, 
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
        metrictimestamp = endTime.to_i.to_s

        Sendit metricpath, metricvalue, metrictimestamp
      rescue
# silently catch error when there's no ReplicaLag metric
      end
    end
  end
end
