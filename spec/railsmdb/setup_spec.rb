# frozen_string_literal: true

require 'spec_helper'

app_name = 'test_app'

describe 'railsmdb setup' do
  clean_context 'when not in a rails app' do
    when_running :railsmdb, 'setup' do
      it_fails
      it_warns 'must be run from the root of an existing Rails application'
    end
  end

  clean_context 'when railsmdb is already present' do
    when_running :railsmdb, 'new', app_name do
      within_folder app_name do
        when_running :railsmdb, 'setup' do
          it_fails
          it_warns 'already configured to use railsmdb'
        end
      end
    end
  end

  clean_context 'when railsmdb is not already present' do
    when_running 'rails', 'new', app_name do
      it_succeeds

      within_folder app_name do
        context 'when declining to run the setup' do
          when_running :railsmdb, 'setup', prompts: { MONGO_SETUP_CONTINUE_PROMPT => "no\n" } do
            it_succeeds
            it_does_not_emit_file 'bin/railsmdb'
            it_does_not_link_file 'bin/rails'
            it_does_not_emit_file 'config/mongoid.yml'
            it_does_not_emit_file 'config/initializers/mongoid.rb'
          end
        end

        context 'when confirming to run the setup' do
          when_running :railsmdb, 'setup', prompts: { MONGO_SETUP_CONTINUE_PROMPT => "yes\n" } do
            it_succeeds
            it_emits_file 'bin/railsmdb'
            it_links_file 'bin/rails', to: 'bin/railsmdb'
            it_emits_file 'config/mongoid.yml'
            it_emits_file 'config/initializers/mongoid.rb'
          end
        end
      end
    end
  end

  context 'when setting up railsmdb with encryption' do
    clean_context 'when declining the customer agreement' do
      when_running 'rails', 'new', app_name do
        it_succeeds

        within_folder app_name do
          when_running :railsmdb, 'setup', '-E',
                       prompts: { MONGO_SETUP_CONTINUE_PROMPT => "yes\n", MONGO_CUSTOMER_PROMPT => "no\n" } do
            it_succeeds

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

    clean_context 'when accepting the customer agreement' do
      when_running 'rails', 'new', app_name do
        it_succeeds

        within_folder app_name do
          when_running :railsmdb, 'setup', '-E',
                       prompts: { MONGO_SETUP_CONTINUE_PROMPT => "yes\n", MONGO_CUSTOMER_PROMPT => "yes\n" } do
            it_succeeds

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
    end
  end
end
