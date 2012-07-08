vacuumetrix
===========

Sucks up metrics from various external sources and put the data into internal systems. 
This is a good thing to do because whilst all the external SAAS services we use are fantastic, it's also sometimes very useful to be able to be able to manipulate the data in one place.  For example, we might want to make a single graph with some internally generated application metrics, with some perfomance metrics from New Relic, with some metrics from an AWS Elastic Load Balancer.  Perhaps.  Anyway, vacuumetrix is a collection of ruby scripts that talks to various APIs and allows the collection of this data in one place.  


##Currently supported Inputs

* New Relic


##Currently supported Outputs

* Graphite


------------
#Installation

##git clone this repo
    cd opt
    git clone https://github.com/99designs/vacuumetrix.git 	

#Configuration
The config.rb file contains all the local configuration variables.

##in the conf directory copy config.rb-sample to config.rb

##New Relic
  * update config.rb with your organization's API key and account 

##Output
 * your graphite server

(Note:  If you haven't already done so you will need to activate the New Relic REST API.  See here: http://blog.newrelic.com/2011/06/20/new-data-api/

#Running the scripts
The scripts are in the bin directory and are designed to be run from cron every minute.

cron:
<pre>
*	*	*	*	*	/opt/vacuumetrix/bin/NewrelicEnduser.rb 123 metricyouwant
</pre>

##NewrelicEnduser.rb
Get New Relic End User (RUM) stats.  Supply two args, app and metric.  

##NewrelicTresholds.rb
Get the threshhold values for all your applications.  This includes average RAM, CPU, DB etc.


#TODO:

##Suck in
 *AWS 
 *Google Analytics

##Spit out 
 *Statsd
 *Ganglia 

Pull requests are appreciated.

