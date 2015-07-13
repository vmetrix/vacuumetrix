## send it
require 'socket'
begin
  require 'system_timer'
  SomeTimer = SystemTimer
rescue LoadError
  require 'timeout'
  SomeTimer = Timeout
end

def SendGraphite(metricpath, metricvalue, metrictimestamp)
  retries = $graphiteretries
  metricpath = "#{$graphiteprefix}.#{metricpath}" if $graphiteprefix && !$graphiteprefix.empty?
	message = metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s
  unless $options[:dryrun]
    begin
      SomeTimer.timeout($graphitetimeout) do
	      sock = TCPSocket.new($graphiteserver, $graphiteport)
	      sock.puts(message)
	      sock.close
      end
    rescue => e
      puts "can't send " + message
      puts "\terror: #{e}"
      retries -= 1
      $sendRetries += 1
      puts "\tretries left: #{retries}"
      retry if retries > 0
    end
  end
  if $options[:verbose]
    puts message
  end
end
