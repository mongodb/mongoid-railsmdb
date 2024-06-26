# frozen_string_literal: true

# This is the template used by the `railsmdb new` command.
# It is not intended to be loaded or used directly, but only as the
# argument to the `--template` option of `rails new`.

require 'railsmdb/helpers'
extend Railsmdb::Helpers

gem 'mongoid', Mongoid::VERSION, comment: 'Use MongoDB for the database, with Mongoid as the ODM'
gem 'railsmdb', Railsmdb::Version::STRING, comment: 'The Rails CLI tool for Mongoid'

# Even with activerecord skipped, we still want the db folder emitted.
build(:db)

confirm_legal_shenanigans
possibly_support_encryption

# this will wind up being called again after the template finishes, but we
# need the mongoid gem installed in the next steps. Ultimately, `run_bundle`
# winds up being called multiple times over the whole process, so it's not a
# big deal.
run_bundle

emit_mongoid_yml
add_encryption_options_to_mongoid_yml

emit_mongoid_initializer
emit_railsmdb
