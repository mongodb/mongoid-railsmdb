# frozen_string_literal: true

require 'spec_helper'
require 'railsmdb/crypt_shared/catalog'

describe Railsmdb::CryptShared::Catalog do
  attr_accessor :catalog

  # avoid reloading and reparsing the catalog dataset for every example.
  before :context do
    dataset = JSON.parse(fixture_from(:dataset, :catalog))
    self.catalog = described_class.new(dataset)
  end

  describe '.current' do
    let(:listing) { class_double(Railsmdb::CryptShared::Listing).as_stubbed_const }

    before { allow(listing).to receive(:fetch).and_return({ 'versions' => [] }) }

    it 'uses Listing.fetch as the data source' do
      catalog = described_class.current
      expect(listing).to have_received(:fetch)
      expect(catalog.listing).to be == { 'versions' => [] }
    end
  end

  describe '#downloads' do
    let(:results) do
      [].tap do |results|
        catalog.downloads(criteria) do |item|
          results.push item
        end
      end
    end

    let(:crypt_shared_urls) { results.map { |dl| dl['crypt_shared']['url'] } }

    context 'when searching on version attributes' do
      let(:criteria) { { production_release: true } }

      it 'excludes records that do not match' do
        expect(crypt_shared_urls).not_to include match(/7.0.0-rc10/)
      end

      it 'includes records that do match' do
        expect(crypt_shared_urls).to include match(/6.0.8/)
      end
    end

    context 'when searching on download attributes' do
      let(:criteria) { { downloads: { target: 'windows' } } }

      it 'only includes records that match' do
        expect(crypt_shared_urls).to all(match(/windows/))
      end
    end
  end

  describe '#optimal_download_url_for_this_host' do
    it 'returns a single download url' do
      expect(catalog.optimal_download_url_for_this_host).to match(%r{^https://})
    end
  end
end
