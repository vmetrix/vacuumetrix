## send it 
def Sendit(message)
  begin
#    puts message
    sock = TCPSocket.new($graphiteserver, 2003)
    sock.puts(message)
    sock.close
  rescue
    puts "can't send"
  end
end
