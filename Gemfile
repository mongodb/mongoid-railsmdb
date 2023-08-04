# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'rake'
  gem 'rspec', '~> 3.12'

  gem 'rubocop', '~> 1.45.1'
  gem 'rubocop-performance', '~> 1.16.0'
  gem 'rubocop-rake', '~> 0.6.0'
  gem 'rubocop-rspec', '~> 2.18.1'

  # these are needed for CI, so that invoking the bin/railsmdb script
  # can see these gems that would normally be made available via the
  # new app's `bundle install`
  gem 'bootsnap'
  gem 'sprockets-rails'
end
