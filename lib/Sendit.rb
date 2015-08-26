## send it to the backends
# NOTE if more than one type of backend is defined, it will send to all

# optionally require the various output libraries
# determine if we're sending to nontagged only, tagged only, or both
# def metric_type()
$send_to = Hash.new
  if !$influxdbserver.to_s.empty?
    require 'SendInfluxDB'
    $send_to[:influxdb] = true
    $send_to[:tagged] = true
    puts "added InfluxDB backend" if $options[:verbose]
  end
  if !$graphiteserver.to_s.empty?
    require 'SendGraphite'
    $send_to[:graphite] = true
    $send_to[:untagged] = true
    puts "added Graphite backend" if $options[:verbose]
  end
  if !$gmondserver.to_s.empty? 
    require 'SendGanglia'
    $send_to[:ganglia] = true
    $send_to[:untagged] = true
    puts "added Ganglia backend" if $options[:verbose]
  end
  if !$opentsdbserver.to_s.empty? 
    require 'SendOpenTSDB'
    $send_to[:opentsdb] = true
    $send_to[:tagged] = true
    puts "added OpenTSDB backend" if $options[:verbose]
  end
# end

def Sendit(metricpath, metricvalue, metrictimestamp, metrictags = nil)
  # Adding in a metrictags guard until all AWS scripts updated
  if $send_to[:influxdb] && metrictags
    SendInfluxDB metricpath, metricvalue, metrictimestamp, metrictags
  end

  if $send_to[:graphite]
    SendGraphite metricpath, metricvalue, metrictimestamp 
  end

  if $send_to[:ganglia]
    SendGanglia metricpath, metricvalue
  end

  if $send_to[:opentsdb]
    SendOpenTSDB metricpath, metricvalue, metrictimestamp, metrictags
  end
end
