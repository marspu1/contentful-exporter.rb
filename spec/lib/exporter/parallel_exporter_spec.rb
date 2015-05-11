require 'spec_helper'
require './lib/contentful/exporter/parallel_exporter'
require './lib/contentful/exporter/configuration'

module Contentful
  module Exporter
    describe ParallelExporter do

      include_context 'shared_configuration'

      before do
        @exporter = ParallelExporter.new(@config)
      end

      it 'number of threads' do
        number = @exporter.number_of_threads
        expect(number).to eq 2
      end

      it 'export entry' do
        vcr('export_entry') do
          raise NotImplementedError
        end
      end

      it 'export asset' do
        vcr('export_asset') do
          raise NotImplementedError
        end
      end

      it 'export content type' do
        vcr('export_content_type') do
          raise NotImplementedError
        end
      end

      context 'create_entry_parameters' do
          raise NotImplementedError
      end

      context 'parse_attributes_from_hash' do
          raise NotImplementedError
      end

      context 'parse_attributes_from_array' do
          raise NotImplementedError
      end
    end
  end
end
