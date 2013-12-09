## send it 
require 'socket'
require 'system_timer'

def SendGraphite(metricpath, metricvalue, metrictimestamp)
  retries = $graphiteretries
  message = ''
  begin
  	SystemTimer.timeout_after($graphitetimeout) do 
	    message = metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s
	    #puts message
	    sock = TCPSocket.new($graphiteserver, $graphiteport)
	    sock.puts(message)
	    sock.close
		end
  rescue => e
    puts "can't send " + message
    puts "\terror: #{e}"
    retries -= 1
    puts "\tretries left: #{retries}"
    retry if retries > 0
  end
end
