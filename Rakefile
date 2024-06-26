# frozen_string_literal: true

require 'bundler'
require 'rubygems/package'
require 'rubygems/security'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w[ -I lib -I spec/support --format documentation ]
end

task default: %i[ spec ]

# This task is used by the release process, but must do nothing except
# print the version number defined by Railsmdb::Version::STRING.
desc 'Prints the version number defined in Railsmdb::Version::STRING'
task :version do
  require_relative 'lib/railsmdb/version'
  puts Railsmdb::Version::STRING
end

task :build do
  abort <<~WARNING
    `rake build` is not used in this project. The gem must be built via the
    "RailsMDB Release" action in GitHub, which is triggered manually when a
    release is ready to publish.
  WARNING
end

# replaces the default Bundler-provided `release` task, which also
# builds the gem. Our release process assumes the gem has already
# been built (and signed via GPG), so we just need `rake release` to
# push the gem to rubygems.
task :release do
  require_relative 'lib/railsmdb/version'

  if ENV['GITHUB_ACTION'].nil?
    abort <<~WARNING
      `rake release` must be invoked from the `RailsMDB Release` GitHub action,
      and must not be invoked locally. This ensures the gem is properly signed
      and distributed by the appropriate user.

      Note that it is the `rubygems/release-gem@v1` step in the `RailsMDB Release`
      action that invokes this task. Do not rename or remove this task, or the
      release-gem step will fail. Reimplement this task with caution.

      railsmdb-#{Railsmdb::Version::STRING}.gem was NOT pushed to RubyGems.
    WARNING
  end

  system 'gem', 'push', "railsmdb-#{Railsmdb::Version::STRING}.gem"
end
