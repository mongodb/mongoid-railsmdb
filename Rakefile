# frozen_string_literal: true

require 'bundler'
require 'bundler/gem_tasks'
require 'rubygems/package'
require 'rubygems/security'
require 'rspec/core/rake_task'

require_relative './lib/railsmdb/version'

def signed_gem?(path_to_gem)
  Gem::Package.new(path_to_gem, Gem::Security::HighSecurity).verify
  true
rescue Gem::Security::Exception => e
  false
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w[ -I lib -I spec/support --format documentation ]
end

task default: %i[ spec ]

Rake::Task['release'].clear

desc 'Release mongoid-railsmdb gem'
task release: %w[ release:require_private_key clobber build release:verify release:tag release:publish ] do
  puts 'here'
end

namespace :release do
  desc 'Requires the private key to be present'
  task :require_private_key do
    unless File.exist?('gem-private_key.pem')
      raise "No private key present, cannot release"
    end
  end

  desc 'Verifies that all built gems in pkg/ are valid'
  task :verify do
    gems = Dir['pkg/*.gem']
    if gems.empty?
      puts 'There are no gems in pkg/ to verify'
    else
      gems.each do |gem|
        if signed_gem?(gem)
          puts "#{gem} is signed"
        else
          abort "#{gem} is not signed"
        end
      end
    end
  end

  desc 'Creates a new tag for the current version'
  task :tag do
    system "git tag -a v#{Railsmdb::Version::STRING} -m 'Tagging release: #{Railsmdb::Version::STRING}'"
    system "git push origin v#{Railsmdb::Version::STRING}"
  end

  desc 'Publishes the most recently built gem'
  task :publish do
    system "gem push pkg/mongoid-railsmdb-#{Railsmdb::Version::STRING}.gem"
  end
end
