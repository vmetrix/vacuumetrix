Gem::Specification.new do |s|
  s.name        = 'vacuumetrix'
  s.version     = '0.0.4'
  s.homepage    = 'https://github.com/99designs/vacuumetrix'
  s.description = <<-EOF
    Sucks up metrics from various external sources and puts the data into internal systems.
  EOF
  s.summary     = "Sucks up metrics from various external sources and puts the data into internal systems."
  s.authors     = ['David Lutz']
  s.executables = %w{
    AWScloudwatchEBS.rb
    AWScloudwatchElasticache.rb
    AWScloudwatchELB.rb
    AWScloudwatchRDS.rb
    AWScountEC2.rb
    facebook.rb
    Neustar.rb
    NewrelicEnduser.rb
    NewrelicThresholds.rb
    twitter_followers.rb
  }

  s.add_dependency "json", "~> 1.7.6"
  s.add_dependency 'gmetric', '~> 0.1.3'
  s.add_dependency 'fog', '~> 1.9.0'
  s.add_dependency 'curb', '~> 0.8.3'
  s.add_dependency 'xml-simple', '~>1.1.2'

  s.files = %w{
    bin/AWScloudwatchEBS.rb
    bin/AWScloudwatchElasticache.rb
    bin/AWScloudwatchELB.rb
    bin/AWScloudwatchRDS.rb
    bin/AWScountEC2.rb
    bin/facebook.rb
    bin/Neustar.rb
    bin/NewrelicEnduser.rb
    bin/NewrelicThresholds.rb
    bin/twitter_followers.rb
    lib/SendGanglia.rb
    lib/SendGraphite.rb
    lib/Sendit.rb
    lib/SendOpenTSDB.rb
    conf/config.rb
  }
end
