## send it 
require 'socket'

def SendGraphite(metricpath, metricvalue, metrictimestamp)
  begin
    message = metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s
    #puts message
    sock = TCPSocket.new($graphiteserver, $graphiteport)
    sock.puts(message)
    sock.close
  rescue
    puts "can't send " + message
  end
end
