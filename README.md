vacuumetrix
===========

Suck up metrics from various sources and spit them into Graphite

Currently supported Inputs:

* New Relic


Currently supported Outputs:

* Graphite


------------
Installation:
git clone this repo

* New Relic

  * copy config.rb-sample to config.rb

  * update config.rb with your organization's API key, account, and your graphite server.

(Note:  you might need to activate the New Relic REST API first.  See here: http://blog.newrelic.com/2011/06/20/new-data-api/


These are the scripts.  You should run them from cron every minute.
getNRenduser.rb
Get New Relic End User (RUM) stats.  Supply two args, app and metric.  

getNRthresh.rb
Get the threshhold values for the app.  This includes average RAM, CPU, DB etc for all your apps.

cron:
<pre>
*	*	*	*	*	/usr/local/vacuumetrix/getNRthresh.rb
</pre>
 

TODO:

Suck in: AWS, Google Analytics

Spit out: Statsd, Ganglia 

