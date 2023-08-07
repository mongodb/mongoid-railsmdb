# frozen_string_literal: true

require 'spec_helper'

app_name = 'test_app'
other_app_name = 'other_app'

describe 'railsmdb new' do
  when_running :railsmdb, 'new', app_name, clean: true do
    it_succeeds

    within_folder app_name do
      it_emits_file 'Gemfile', containing: %w[ mongoid railsmdb ], without: 'sqlite3'
      it_emits_file 'bin/railsmdb'
      it_links_file 'bin/rails', to: 'bin/railsmdb'
      it_emits_file 'config/mongoid.yml', containing: "database: #{app_name}_development"
      it_emits_file 'config/initializers/mongoid.rb', containing: 'Mongoid.configure do'
      it_does_not_emit_file 'config/database.yml'
      it_emits_file 'db/seeds.rb'
      it_does_not_emit_file 'app/models/application_record.rb'

      when_running :railsmdb, 'new', other_app_name do
        it_fails
        it_prints 'Can\'t initialize a new Rails application within the directory of another'
        it_does_not_emit_folder other_app_name
      end
    end
  end

  when_running :railsmdb, 'new', app_name, '--no-skip-active-record', clean: true do
    it_succeeds

    within_folder app_name do
      it_emits_folder 'db'
      it_emits_file 'Gemfile', containing: %w[ mongoid railsmdb sqlite3 ]
      it_emits_file 'config/database.yml', containing: 'sqlite3'
      it_emits_file 'config/mongoid.yml'
      it_emits_file 'app/models/application_record.rb'
    end
  end

  context 'when accepting the customer agreement' do
    when_running :railsmdb, 'new', app_name, '-E',
                 prompts: { MONGO_CUSTOMER_PROMPT => "yes\n" },
                 clean: true do
      it_succeeds

      within_folder app_name do
        it_emits_file 'Gemfile', containing: %w[ ffi libmongocrypt-helper ]
        it_stores_credentials_for 'mongodb_master_key'
        it_emits_entry_matching 'vendor/crypt_shared/mongo_crypt_v1.*'
        it_emits_file 'config/mongoid.yml',
                      containing: [
                        '# This client is used to obtain the encryption keys',
                        /crypt_shared_lib_path: .*'vendor', 'crypt_shared', 'mongo_crypt_v1/,
                        '# Setting it to true is recommended for auto encryption'
                      ]
      end
    end
  end

  context 'when declining the customer agreement' do
    when_running :railsmdb, 'new', app_name, '-E',
                 prompts: { MONGO_CUSTOMER_PROMPT => "no\n" },
                 clean: true do
      it_succeeds

      within_folder app_name do
        it_emits_file 'Gemfile', without: %w[ ffi libmongocrypt-helper ]
        it_does_not_store_credentials_for 'mongodb_master_key'
        it_does_not_emit_folder 'vendor/crypt_shared'
        it_emits_file 'config/mongoid.yml',
                      without: [
                        '# This client is used to obtain the encryption keys',
                        /crypt_shared_lib_path: .*'vendor', 'crypt_shared', 'mongo_crypt_v1/,
                        '# Setting it to true is recommended for auto encryption'
                      ]
      end
    end
  end
end
