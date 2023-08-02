# frozen_string_literal: true

require 'spec_helper'
require 'railsmdb/crypt_shared/listing'

describe Railsmdb::CryptShared::Listing do
  let(:stubbed_uri) { class_double('URI').as_stubbed_const }

  def pretend_uri(uri, returns: nil)
    uri_inst = instance_double('URI::HTTPS', read: returns)

    expectation = expect(stubbed_uri)
    if returns.nil?
      expectation.not_to receive(:parse)
    else
      expectation.to receive(:parse).with(uri).and_return(uri_inst)
    end
  end

  let(:listing) { described_class.new }
  let(:raw_catalog) { fixture_from(:dataset, :catalog) }

  context '#listing' do
    before { FileUtils.rm_rf described_class::CURRENT_CACHE }

    context 'when not cached' do
      before { pretend_uri described_class::CURRENT_URI, returns: raw_catalog }

      it 'makes web request' do
        listing.listing
      end

      it 'populates the cache' do
        listing.listing
        expect(File.read(described_class::CURRENT_CACHE)).to be == raw_catalog
      end
    end

    context 'when cached' do
      before { pretend_uri described_class::CURRENT_URI, returns: nil }
      before { File.write(described_class::CURRENT_CACHE, raw_catalog) }

      it 'does not make the web request' do
        listing.listing
      end

      it 'reads the cache' do
        expect(listing.listing).to be == JSON.parse(raw_catalog)
      end
    end
  end
end
