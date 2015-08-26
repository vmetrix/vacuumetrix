require 'gmetric'

def SendGanglia(metricpath, metricvalue)
  unless $options[:dryrun]
    begin
      Ganglia::GMetric.send($gmondserver, $gmondport, {
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
  if $options[:verbose]
    puts ":name => #{metricpath}, :units => '', :type => 'float', :value => #{metricvalue.to_f}, :tmax => 60, :dmax => 60"
  end
end
