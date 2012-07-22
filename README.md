vacuumetrix
===========

Sucks up metrics from various external sources and puts the data into internal systems. 
This is a good thing to do because whilst all the external SAAS services we use are fantastic, it's also sometimes very useful to be able to be able to view and manipulate the data in one place.  For example, we might want to make a single graph with some internally generated application metrics, with some perfomance metrics from New Relic, with some metrics from an AWS Elastic Load Balancer.  Perhaps.  Anyway, vacuumetrix is a collection of ruby scripts that talk to various APIs and allows the collection of this data in one place.  


##Currently supported Inputs

* New Relic
* AWS Cloudwatch (some services)
* Neustar Web Performance Management

##Currently supported Outputs

* Graphite
* Ganglia

------------
#Installation

##git clone this repo
    cd /opt
    git clone https://github.com/99designs/vacuumetrix.git 	

#Configuration
The config.rb file contains all the local configuration variables.

    cd conf 
    cp config.rb-sample  config.rb

##New Relic
 update config.rb with your organization's API key and account number

##AWS
 update config.rb with your organization's AWSAccessKeyId and AWSSecretKey with permission to read the Cloudwatch API

##Neustar
  update config.rb with your organization's API Key and Secret

##Output
 your Graphite server
 your Ganglia-gmond server

(Note:  If you haven't already done so you will need to activate the New Relic REST API.  See here: http://blog.newrelic.com/2011/06/20/new-data-api/

#Running the scripts
The scripts are in the bin directory and are designed to be run from cron every minute.

cron:
<pre>
*	*	*	*	*	/opt/vacuumetrix/bin/NewrelicEnduser.rb 123 metricyouwant
</pre>

##NewrelicEnduser.rb
Get New Relic End User (RUM) stats.  Supply two args, app and metric.  

##NewrelicThresholds.rb
Get the threshhold values for all your applications.  This includes average RAM, CPU, DB etc.

##AWScloudwatchEBS.rb
Get EBS metrics.  No arguments.  Run every 5 minutes. No point running more frequently.

##AWScloudwatchELB.rb
Get Elastic Load Balancer metrics.  Supply the name of the ELB.

##AWScloudwatchRDS.rb
Get RDS  metrics.  Supply the name of the Relational Database Service instance. (Tested with MySQL).  YMMV.

##AWScountEC2.rb
Count the number of EC2 instances of each flavor.  No arguments.

##Neustar.rb
Get Neustar Web Performance Metrics.  For each monitor get duration and status for each monitored location.  No arguments.  Run every 5 minutes.  (Not very efficient at the moment.  Needs some tuning).


#TODO

##Suck in

* Other AWS metrics (EBS)
* Google Analytics

##Spit out 

* Statsd
* OpenTSDB

------------
Pull requests are appreciated.

