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
  if $send_to[:influxdb]
    SendInfluxDB metricpath, metricvalue, metrictimestamp, metrictags
  end

  if $send_to[:graphite]
    SendGraphite metricpath, metricvalue, metrictimestamp 
  end

  if $send_to[:ganglia]
    SendGanglia metricpath, metricvalue
  end

  if $send_to[:opentsdb]
    # OpenTSDB requires at least one tag, if we don't extract them, make one
    tags = ''
    unless metrictags
      a = metricpath.split(/\./,2)
      metricpath = a[0]
      metrictags = "tag=" + a[1]
    end
    SendOpenTSDB metricpath, metricvalue, metrictimestamp, metrictags
  end
end
