## send it to the backends
require '/opt/vacuumetrix/lib/SendGraphite.rb'
require '/opt/vacuumetrix/lib/SendGanglia.rb'

def Sendit(metricpath, metricvalue, metrictimestamp)
  unless $graphiteserver.empty?
#	puts metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s 
  	SendGraphite metricpath, metricvalue, metrictimestamp 
  end

  unless $gmondserver.empty?
  	SendGanglia metricpath, metricvalue
  end

end
