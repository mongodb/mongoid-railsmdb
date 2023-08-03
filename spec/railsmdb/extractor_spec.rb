# frozen_string_literal: true

require 'spec_helper'
require 'railsmdb/extractor'

describe Railsmdb::Extractor do
  describe '.for' do
    let(:extractor) { described_class.for(archive_path) }

    context 'when given a path to a zip file' do
      let(:archive_path) { '/path/to/file.zip' }

      it 'sets archive path' do
        expect(extractor.archive_path).to be == archive_path
      end

      it 'returns a ZipExtractor' do
        expect(extractor).to be_a Railsmdb::ZipExtractor
      end
    end

    %w[ tgz tar.gz ].each do |ext|
      context "when given a path to a #{ext} file" do
        let(:archive_path) { "/path/to/file.#{ext}" }

        it 'sets archive path' do
          expect(extractor.archive_path).to be == archive_path
        end

        it 'returns a TarGzipExtractor' do
          expect(extractor).to be_a Railsmdb::TarGzipExtractor
        end
      end
    end
  end

  {
    'zip' => Railsmdb::ZipExtractor,
    'tgz' => Railsmdb::TarGzipExtractor,
    'tar.gz' => Railsmdb::TarGzipExtractor
  }.each do |ext, extractor_class|
    describe extractor_class do
      describe '#extract' do
        let(:archive) { fixture_path_for(:archive, "archive.#{ext}") }
        let(:extractor) { described_class.new(archive) }

        let(:results) do
          {}.tap do |results|
            results[:return] = extractor.extract(filename) do |n, c|
              results[:name] = n
              results[:content] = c
            end
          end
        end

        let(:extracted_name) { results[:name] }
        let(:extracted_contents) { results[:content] }
        let(:return_value) { results[:return] }

        context 'when the entry does not exist' do
          let(:filename) { 'bogus/entry.txt' }

          it 'does not invoke the block' do
            expect(extracted_name).to be_nil
          end

          it 'returns nil' do
            expect(return_value).to be_nil
          end
        end

        context 'when the entry exists' do
          let(:filename) { 'foo/bar/bar.txt' }

          it 'returns the name of the extracted file' do
            expect(return_value).to be == filename
          end

          it 'yields the name of the extracted file' do
            expect(extracted_name).to be == filename
          end

          it 'yields the contents of the extracted file' do
            expect(extracted_contents).to be == "one\ntwo\nthree\n\n"
          end
        end
      end
    end
  end
end
