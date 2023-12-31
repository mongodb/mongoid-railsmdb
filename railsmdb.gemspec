# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'railsmdb/version'

Gem::Specification.new do |s|
  s.name        = 'railsmdb'
  s.version     = Railsmdb::Version::STRING
  s.authors     = [ 'The MongoDB Ruby Team' ]
  s.email       = 'dbx-ruby@mongodb.com'
  s.homepage    = 'https://github.com/mongodb/mongoid-railsmdb'
  s.summary     = 'CLI for creating and managing Rails projects that use Mongoid'
  s.description = 'A CLI for assisting Rails programmers in creating and ' \
                  'managing Rails projects that use Mongoid and MongoDB as ' \
                  'the datastore.'
  s.license     = 'Apache-2.0'

  # FIXME: populate the metadata fields
  s.metadata = {
    'rubygems_mfa_required' => 'true',
    'bug_tracker_uri' => 'https://jira.mongodb.org/projects/MONGOID',
    'changelog_uri' => 'https://github.com/mongodb/mongoid-railsmdb/releases',
    'documentation_uri' => 'https://github.com/mongodb/mongoid-railsmdb/blob/v1.0.0.alpha1/README.md',
    'homepage_uri' => 'https://github.com/mongodb/mongoid-railsmdb',
    'source_code_uri' => 'https://github.com/mongodb/mongoid-railsmdb'
  }

  if File.exist?('gem-private_key.pem')
    s.signing_key = 'gem-private_key.pem'
    s.cert_chain  = [ 'gem-public_cert.pem' ]
  end

  s.files  = %w[ LICENSE README.md ]
  s.files += Dir.glob('{bin,lib}/**/*')

  s.executables << 'railsmdb'

  s.add_dependency 'rails', '~> 7.0'
  s.add_dependency 'os', '~> 1.1'
  s.add_dependency 'faraday', '~> 2.7'
  s.add_dependency 'minitar', '~> 0.9'
  s.add_dependency 'rubyzip', '~> 2.3'
  s.add_dependency 'mongoid', '>= 8.0'

  s.required_ruby_version = '>= 3.0'
end
