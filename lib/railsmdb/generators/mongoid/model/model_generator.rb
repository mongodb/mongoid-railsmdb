# frozen_string_literal: true

require 'rails/generators/named_base'

module Mongoid
  module Generators
    # Generator implementation for creating a new model.
    class ModelGenerator < Rails::Generators::NamedBase
      desc 'Creates a Mongoid model'
      argument :attributes, type: :array, default: [], banner: 'field:type field:type'

      check_class_collision

      def self.base_root
        File.expand_path('../..', __dir__)
      end

      class_option :timestamps, type: :boolean, default: true
      class_option :parent,     type: :string, desc: 'The parent class for the generated model'
      class_option :collection, type: :string, desc: 'The collection for storing model\'s documents'

      # Task for creating a new model file
      def create_model_file
        template 'model.rb.tt', File.join('app/models', class_path, "#{file_name}.rb")
      end

      hook_for :test_framework

      private

      def type_class_for(attribute)
        case attribute.type
        when :datetime then 'Time'
        when :text then 'String'
        when :boolean then 'Mongoid::Boolean'
        else attribute.type.to_s.classify
        end
      end
    end
  end
end
