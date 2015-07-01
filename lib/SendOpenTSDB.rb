## send it 
# put <metric> <timestamp> <value> <tagk1=tagv1[ tagk2=tagv2 ...tagkN=tagvN]>
# put sys.cpu.user 1356998400 42.5 host=webserver01 cpu=0

require 'socket'
def SendOpenTSDB(metricpath, metricvalue, metrictimestamp, metrictags = nil)
  # OpenTSDB requires at least one tag, if we don't extract them, make one
  tags = ''
  unless metrictags
    a = metricpath.split(/\./,2)
    metricpath = a[0]
    metrictags[:tag] = a[1]
  end
          ### we need to turn each kv pair in metrictags[:foo] into foo=bar joined by ' '
  message = "put " + metricpath + " " + metrictimestamp.to_s + " " + metricvalue.to_s + " " + metrictags.each do |tag|
  unless options[:dryrun]
    begin
      sock = TCPSocket.new($opentsdbserver, $opentsdbport)
      sock.puts(message)
      sock.close
    rescue
      puts "can't send"
    end
  end
  if options[:verbose]
    puts message
  end
end
