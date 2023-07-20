# frozen_string_literal: true

require 'rails/app_loader'
require 'railsmdb/ext/rails/command'
require 'railsmdb/ext/rails/generators/rails/app/app_generator'

# the EXECUTABLES constant might eventually be frozen, so we should do
# this the long, difficult way...
Rails::AppLoader.send :remove_const, :EXECUTABLES
Rails::AppLoader::EXECUTABLES = %w[ bin/railsmdb ].freeze

require 'rails/cli'
