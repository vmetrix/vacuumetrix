require '/opt/vacuumetrix/lib/SendGraphite.rb'
## send it to the backends
def Sendit(metricpath, metricvalue, metrictimestamp)
unless $graphiteserver.empty?
#	puts metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s 
  	SendGraphite metricpath, metricvalue, metrictimestamp 
end

end
