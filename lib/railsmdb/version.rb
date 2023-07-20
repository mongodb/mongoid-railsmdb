# frozen_string_literal: true

module Railsmdb
  module Version
    MAJOR  = 0
    MINOR  = 0
    PATCH  = 1
    SUFFIX = nil # pre-release, alpha, beta, etc.

    STRING = [ MAJOR, MINOR, PATCH, SUFFIX ].compact.join('.')
  end
end
