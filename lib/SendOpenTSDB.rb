## send it 
require 'socket'
def SendOpenTSDB(metricpath, metricvalue, metrictimestamp, tag)
  begin
    message = "put " + metricpath + " " + metrictimestamp.to_s + " " + metricvalue.to_s + " " + tag
#    puts message
    sock = TCPSocket.new($opentsdbserver, $opentsdbport)
    sock.puts(message)
    sock.close
  rescue
    puts "can't send"
  end
end
