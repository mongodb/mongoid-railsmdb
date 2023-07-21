# frozen_string_literal: true

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w[ -I lib -I spec/support --format documentation ]
end

task default: %i[ spec ]
