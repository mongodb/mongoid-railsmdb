# frozen_string_literal: true

require 'spec_helper'
require 'railsmdb/crypt_shared/listing'

describe Railsmdb::CryptShared::Listing do
  let(:stubbed_uri) { class_double(URI).as_stubbed_const(transfer_nested_constants: true) }
  let(:listing) { described_class.new }
  let(:raw_catalog) { fixture_from(:dataset, :catalog) }
  let(:uri_contents) { nil }
  let(:uri_inst) { instance_double(URI::HTTPS, read: uri_contents) }

  before do
    allow(stubbed_uri)
      .to receive(:parse)
      .with(described_class::CURRENT_URI)
      .and_return uri_inst
  end

  describe '#listing' do
    before { FileUtils.rm_rf described_class::CURRENT_CACHE }

    context 'when not cached' do
      let(:uri_contents) { raw_catalog }

      it 'makes web request' do
        listing.listing
        expect(stubbed_uri).to have_received(:parse)
      end

      it 'populates the cache' do
        listing.listing
        expect(File.read(described_class::CURRENT_CACHE)).to be == raw_catalog
      end
    end

    context 'when cached' do
      before { File.write(described_class::CURRENT_CACHE, raw_catalog) }

      it 'does not make the web request' do
        listing.listing
        expect(stubbed_uri).not_to have_received(:parse)
      end

      it 'reads the cache' do
        expect(listing.listing).to be == JSON.parse(raw_catalog)
      end
    end
  end
end
