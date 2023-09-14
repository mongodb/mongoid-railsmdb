# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require 'bundler'
require 'bundler/gem_tasks'
require 'rubygems/package'
require 'rubygems/security'
require 'rspec/core/rake_task'

require_relative './lib/railsmdb/version'

def signed_gem?(path_to_gem)
  Gem::Package.new(path_to_gem, Gem::Security::HighSecurity).verify
  true
rescue Gem::Security::Exception
  false
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w[ -I lib -I spec/support --format documentation ]
end

task default: %i[ spec ]

Rake::Task['release'].clear

desc 'Release railsmdb gem'
task release: %w[ release:require_private_key clobber build release:verify release:tag release:publish ]

namespace :release do
  desc 'Requires the private key to be present'
  task :require_private_key do
    raise 'No private key present, cannot release' unless File.exist?('gem-private_key.pem')
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
    system "git push upstream v#{Railsmdb::Version::STRING}"
  end

  desc 'Publishes the most recently built gem'
  task :publish do
    system "gem push pkg/railsmdb-#{Railsmdb::Version::STRING}.gem"
  end
end

# rubocop:enable Metrics/BlockLength
