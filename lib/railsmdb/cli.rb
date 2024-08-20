# frozen_string_literal: true

require 'railsmdb/ext/rails/command'
require 'railsmdb/generators/extensions/app_loader'
require 'railsmdb/generators/extensions/app_generator'

if ARGV.first == 'setup'
  Rails::Command.invoke :setup, ARGV
else
  require 'rails/cli'
end
