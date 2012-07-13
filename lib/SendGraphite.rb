## send it 
def SendGraphite(metricpath, metricvalue, metrictimestamp)
  begin
    message = metricpath + " " + metricvalue.to_s + " " + metrictimestamp.to_s
#    puts message
    sock = TCPSocket.new($graphiteserver, 2003)
    sock.puts(message)
    sock.close
  rescue
    puts "can't send"
  end
end
