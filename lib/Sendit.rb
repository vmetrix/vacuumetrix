## send it to the backends

def Sendit(metricpath, metricvalue, metrictimestamp)
  if !$graphiteserver.nil? and !$graphiteserver.empty?
        require 'SendGraphite'
	# puts metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s 
  	SendGraphite metricpath, metricvalue, metrictimestamp 
  end

  if !$gmondserver.nil? and !$gmondserver.empty? 
	require 'SendGanglia'
	SendGanglia metricpath, metricvalue
  end

  if !$opentsdbserver.nil? and !$opentsdbserver.empty? 
	require 'SendOpenTSDB'
	a = metricpath.split(/\./,2)
	metric = a[0]
	tag = a[1]
	# Note: I really don't know if this is a sensible way to do this for
	# OpenTSDB... anyone have feedback? (dlutzy)
	SendOpenTSDB metric, metricvalue, metrictimestamp, "tag=" + tag
  end
end
