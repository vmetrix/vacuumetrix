## send it to the backends
require '/opt/vacuumetrix/lib/SendGraphite.rb'
require '/opt/vacuumetrix/lib/SendGanglia.rb'

def Sendit(metricpath, metricvalue, metrictimestamp)
  if !$graphiteserver.nil? and !$graphiteserver.empty?
#	puts metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s 
  	SendGraphite metricpath, metricvalue, metrictimestamp 
  end

  if !$gmondserver.nil? and !$gmondserver.empty? 
	SendGanglia metricpath, metricvalue
  end

end
