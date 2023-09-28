# frozen_string_literal: true

module Railsmdb
  module Version
    MAJOR  = 1
    MINOR  = 0
    PATCH  = 0
    SUFFIX = 'alpha3' # pre-release, alpha, beta, etc.

    STRING = [ MAJOR, MINOR, PATCH, SUFFIX ].compact.join('.')
  end
end
