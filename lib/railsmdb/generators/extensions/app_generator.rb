# frozen_string_literal: true

require 'rails/generators/rails/app/app_generator'

module Mongoid
  module Generators
    # Module for containing extensions relating to generators.
    module Extensions
      # Extension module for the Rails::Generators::AppGenerator
      # generator.
      module AppGenerator
        extend ActiveSupport::Concern

        included do
          # change the --template option to default to our mongoid application
          # template.
          class_option :template, type: :string,
                                  aliases: '-m',
                                  default: File.expand_path(File.join(__dir__, '../../template.rb')),
                                  desc: 'Path to an application template (can be a filesystem path or URL)'

          # change the --skip-active-record option to default to true. Users
          # may pass --no-skip-active-record to enable it again, if they want
          # to use both Mongoid and ActiveRecord.
          class_option :skip_active_record,
                       type: :boolean,
                       aliases: '-O',
                       default: true,
                       desc: 'Skip Active Record files (use --no-skip-active-record to explicitly enable them)'

          # An option for enabling MongoDB encryption features in the new app.
          class_option :encryption, type: :boolean,
                                    aliases: '-E',
                                    default: false,
                                    desc: 'Add gems and configuration to enable MongoDB encryption features'

          # Add an option for accepting the customer agreement related to
          # MongoDB enterprise, allowing the acceptance prompt to be skipped.
          class_option :accept_customer_agreement, type: :boolean,
                                                   desc: 'Accept the MongoDB Customer Agreement'
        end
      end

      ::Rails::Generators::AppGenerator.include AppGenerator
    end
  end
end
