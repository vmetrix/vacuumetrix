require 'gmetric'

def SendGanglia(metricpath, metricvalue)
  begin
    Ganglia::GMetric.send($gmondserver, 8649, {
    :name => metricpath,
    :units => '',
    :type => 'float',     
    :value => metricvalue.to_f,    
    :tmax => 60,          
    :dmax => 60          
  })
  rescue
    puts "can't send to ganglia/gmond"
  end
end
