vacuumetrix
===========

Sucks up metrics from various external sources and puts the data into internal systems. 
This is a good thing to do because whilst all the external SAAS services we use are fantastic, it's also sometimes very useful to be able to be able to view and manipulate the data in one place.  For example, we might want to make a single graph with some internally generated application metrics, with some perfomance metrics from New Relic, with some metrics from an AWS Elastic Load Balancer.  Perhaps.  Anyway, vacuumetrix is a collection of ruby scripts that talk to various APIs and allows the collection of this data in one place.  


##Currently supported Inputs

* New Relic
* AWS Cloudwatch (some services)
* Neustar Web Performance Management
* facebook "likes"
* twitter "followers"

##Currently supported Outputs

* Graphite
* Ganglia
* OpenTSDB

------------
#Installation

##git clone this repo
    git clone https://github.com/99designs/vacuumetrix.git 	

## Install dependancies
### Debian/Ubuntu

    apt-get install ruby build-essential libcurl3 libcurl3-gnutls libcurl4-openssl-dev

### Ruby Gems

    gem install json 

If you're outputting to ganglia gmond you'll also need to
    
    gem install gmetric

#Configuration
The config.rb file contains all the local configuration variables.

    cd conf 
    cp config.rb-sample config.rb

##New Relic
 update config.rb with your organization's API key and account number

    gem install curb xml-simple

##AWS
 update config.rb with your organization's AWSAccessKeyId and AWSSecretKey with permission to read the Cloudwatch API

    gem install fog

##Neustar
  update config.rb with your organization's API Key and Secret

    gem install curb time

##Twitter

    gem install curb


#Running the scripts
The scripts are in the bin directory and are designed to be run from cron every minute.
Generally if no argument is supplied to the script it'll grab all the metrics.  If an argument is supplied it'll be more specific.

cron:
<pre>
*	*	*	*	*	/opt/vacuumetrix/bin/NewrelicEnduser.rb 123 metricyouwant
</pre>

##NewrelicEnduser.rb
(Note:  If you haven't already done so you will need to activate the New Relic REST API.  See here: http://blog.newrelic.com/2011/06/20/new-data-api/
Get New Relic End User (RUM) stats.  Supply two args, app and metric.  

##NewrelicThresholds.rb
Get the threshhold values for all your applications.  This includes average RAM, CPU, DB etc.

##AWScloudwatchEBS.rb
Get EBS metrics.  No arguments.  Run every 5 minutes. No point running more frequently.

##AWScloudwatchELB.rb
Get Elastic Load Balancer metrics.  Supply the name of the ELB or multiple ELBs and and optionally --start-offset and --end-offset (in seconds).

##AWScloudwatchRDS.rb
Get RDS metrics.  Optionally supply the name of the Relational Database Service instance. (Tested with MySQL).  YMMV.

##AWScountEC2.rb
Count the number of EC2 instances of each flavor.  No arguments.

##AWScloudwatchElasticache.rb
Get Elasticache metrics.  Interesting ones anyway.  No arguments.

##AWScloudwatchDynamo.rb
Get DynamoDB metrics. Specify table_name as argument and optionally --start-offset and --end-offset (in seconds). 

##Neustar.rb
Get Neustar Web Performance Metrics.  For each monitor get duration and status for each monitored location.  No arguments.  Run every 5 minutes.  (Not very efficient at the moment.  Needs some tuning).

##facebook.rb
Argument is the name of the page you want to check the like count of. 

##twitter.rb
Argument is the name of the twitter user you want to check the number of followers of. 

#TODO

##Suck in

* Other AWS metrics 
* Google Analytics

##Spit out 

* Statsd

------------
Follow vacuumetrix on twitter for updates https://twitter.com/vacuumetrix
Pull requests are appreciated.

