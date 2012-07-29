## send it to the backends
require '/opt/vacuumetrix/lib/SendGraphite.rb'
require '/opt/vacuumetrix/lib/SendGanglia.rb'
require '/opt/vacuumetrix/lib/SendOpenTSDB.rb'

def Sendit(metricpath, metricvalue, metrictimestamp)
  if !$graphiteserver.nil? and !$graphiteserver.empty?
#	puts metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s 
  	SendGraphite metricpath, metricvalue, metrictimestamp 
  end

  if !$gmondserver.nil? and !$gmondserver.empty? 
	SendGanglia metricpath, metricvalue
  end

  if !$opentsdbserver.nil? and !$opentsdbserver.empty? 
	a = metricpath.split(/\./,2)
	metric = a[0]
	tag = a[1]
#Note: I really don't know if this is a sensible way to do this for OpenTSDB... anyone have feedback? (dlutzy)
	SendOpenTSDB metric, metricvalue, metrictimestamp, "tag=" + tag
  end
end
