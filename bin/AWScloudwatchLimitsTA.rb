#!/usr/bin/env ruby
## grab AWS limits from Trusted Advisor
### gem install aws-sdk --no-ri --no-rdoc

$:.unshift File.join(File.dirname(__FILE__), *%w[.. conf])
$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])

require 'config'
require 'Sendit'
require 'rubygems' if RUBY_VERSION < "1.9"
require 'json'
require 'aws-sdk'
require 'optparse'

options = {
    :start_offset => 180,
    :end_offset => 120
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: AWScloudwatchLimitsTA.rb [options]"

  opts.on('-d', '--dryrun', 'Dry run, does not send metrics') do |d|
    options[:dryrun] = d
  end

  opts.on('-v', '--verbose', 'Run verbosely') do |v|
    options[:verbose] = v
  end

  opts.on('-h', '--help', '') do
    puts opts
    exit
  end
end

optparse.parse!

startTime = Time.now.utc.to_i.to_s

creds = Aws::Credentials.new($awsaccesskey, $awssecretkey)
# Note that Support only has one region http://docs.aws.amazon.com/general/latest/gr/rande.html#awssupport_region
support = Aws::Support::Client.new(region:'us-east-1', credentials:creds)

advisor_checks = support.describe_trusted_advisor_checks({
  language: "en",
})
limits_id = ''
advisor_checks[0].each do |check|
  limits_id = check.id if check.name == "Service Limits"
end

results = support.describe_trusted_advisor_check_result({
  check_id: limits_id,
  language: "en",
})

# Example:
# status="ok", region="ap-southeast-2", resource_id="ABC", is_suppressed=false, 
#   metadata=["ap-southeast-2", "RDS", "DB security groups", "25", "1", "Green"]>
results.result.flagged_resources.each do |result|
  region = result['metadata'][0]
  service = result['metadata'][1]
  check = result['metadata'][2].tr(' ', '_').tr('(', '').tr(')', '').gsub(/\-_/, '')
  max = result['metadata'][3]
  current = result['metadata'][4]
  metricpath = "AWSLimitsTA.#{region}.#{service}.#{check}"

  Sendit "#{metricpath}.max", max, startTime unless options[:dryrun]
  puts "#{metricpath}.max #{max} #{startTime}" if options[:verbose]

  # the RI limits only have a max, current value appears to always be nil
  if current
    Sendit "#{metricpath}.value", current, startTime unless options[:dryrun]
    puts "#{metricpath}.value #{current} #{startTime}" if options[:verbose]
    Sendit "#{metricpath}.used_percent", (current.to_i * 100 / max.to_i), startTime unless options[:dryrun]
    puts "#{metricpath}.used_percent #{(current.to_i * 100 / max.to_i)} #{startTime}" if options[:verbose]
  end
end

exit 0
