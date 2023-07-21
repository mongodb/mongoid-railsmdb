# frozen_string_literal: true

require 'spec_helper'

APP_NAME = 'test_app'
OTHER_APP_NAME = 'other_app'

describe 'railsmdb new' do
  when_running_railsmdb 'new', APP_NAME do
    it_succeeds

    within_folder APP_NAME do
      it_emits_file 'Gemfile', containing: %w[ mongoid railsmdb ], without: 'sqlite3'
      it_emits_file 'bin/railsmdb'
      it_links_file 'bin/rails', to: 'bin/railsmdb'
      it_emits_file 'config/mongoid.yml', containing: "database: #{APP_NAME}_development"
      it_emits_file 'config/initializers/mongoid.rb', containing: 'Mongoid.configure do'
      it_does_not_emit_file 'config/database.yml'
      it_does_not_emit_folder 'db'
      it_does_not_emit_file 'app/models/application_record.rb'

      when_running_bin_railsmdb 'new', OTHER_APP_NAME do
        it_fails
        it_prints 'Can\'t initialize a new Rails application within the directory of another'
        it_does_not_emit_folder OTHER_APP_NAME
      end
    end
  end

  when_running_railsmdb 'new', APP_NAME, '--no-skip-active-record' do
    it_succeeds

    within_folder APP_NAME do
      it_emits_folder 'db'
      it_emits_file 'Gemfile', containing: %w[ mongoid railsmdb sqlite3 ]
      it_emits_file 'config/database.yml', containing: 'sqlite3'
      it_emits_file 'config/mongoid.yml'
      it_emits_file 'app/models/application_record.rb'
    end
  end
end
