# frozen_string_literal: true

require 'spec_helper'

app_name = 'test_app'
missing_program = '/path/to/missing/program'

describe 'railsmdb dbconsole' do
  # Helper method for replacing the generated app's config/mongoid.yml file
  # with the given fixture file.
  def self.write_mongoid_yml_with(features)
    before(:context) do
      write_file(
        'config/mongoid.yml',
        fixture_from(:config, "mongoid_yml_with_#{features}")
      )
    end
  end

  when_running_railsmdb 'new', app_name do
    it_succeeds

    within_folder app_name do
      context 'when mongosh is installed' do
        write_mongoid_yml_with(:db_and_hosts)

        # we're replacing `mongosh` with `echo`, so we can confirm that the
        # command is run with the expected parameters.
        when_running_bin_railsmdb 'dbconsole', env: { MONGOSH_CMD: 'echo' } do
          it_succeeds
          it_prints 'mongodb://host1.com:1234/test_app_development'
          it_warns 'no development configuration'
        end
      end

      context 'when mongosh is not installed' do
        when_running_bin_railsmdb 'dbconsole',
                                  env: { MONGOSH_CMD: missing_program } do
          it_fails
          it_warns 'mongosh is not installed'
        end
      end

      context 'when mongoid.yml specifies a uri' do
        write_mongoid_yml_with(:uri)

        when_running_bin_railsmdb 'dbconsole', env: { MONGOSH_CMD: 'echo' } do
          it_succeeds
          it_prints 'mongodb://user:password@mongodb.domain.com:27017/test_app_development'
        end
      end
    end
  end
end
