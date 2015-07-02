## send it

require 'net/http'
require 'uri'
unless $SomeTimer
  begin
    require 'system_timer'
    $SomeTimer = SystemTimer
  rescue LoadError
    require 'timeout'
    $SomeTimer = Timeout
  end
end

# SendInfluxDB('CPUUtilization', 'instance_id=i-abcd1234,region=us-west-2,name=influxdb9_test,CostCenter=12345,Owner=me@example_com,Service=metrics', 5, #DATE)
def SendInfluxDB(metricpath, metricvalue, metrictimestamp, metrictags = nil)
  retries = $influxdbretries
  my_tags_string = metrictags.map{|k, v| "#{k}=#{v.to_s}"}.join(',')
  message = metricpath.split('.').last + ',' + my_tags_string + ' value=' + metricvalue.to_s + ' ' + metrictimestamp

  unless $options[:dryrun]
    begin
      $SomeTimer.timeout($influxdbtimeout) do
	uri = URI("http://#{$influxdbserver}:#{$influxdbport}/write?db=#{$influxdbdatabase}&precision=s")
	req = Net::HTTP::Post.new(uri)
	req.body = message
	req.content_type = 'application/x-www-form-urlencoded'

	response = Net::HTTP.start(uri.hostname, uri.port) do |http|
	  http.request(req)
	end
      end
    rescue => e
      puts "can't send " + message
      puts "\terror: #{e}"
      retries -= 1
      puts "\tretries left: #{retries}"
      retry if retries > 0
    end
  end
  if $options[:verbose]
    puts message
  end
end
