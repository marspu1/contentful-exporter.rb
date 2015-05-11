require 'spec_helper'
require './lib/contentful/exporter/configuration'

module Contentful
  module Exporter
    describe Configuration do

      include_context 'shared_configuration'

      it 'initialize' do
        expect(@config.data_dir).to eq 'spec/fixtures/export_files'
        expect(@config.collections_dir).to eq 'spec/fixtures/export_files/collections'
        expect(@config.assets_dir).to eq 'spec/fixtures/export_files/assets'
        expect(@config.entries_dir).to eq 'spec/fixtures/export_files/entries'
        expect(@config.log_files_dir).to eq 'spec/fixtures/export_files/logs'
        expect(@config.threads_dir).to eq 'spec/fixtures/export_files/threads'
        expect(@config.exported_entries).to be_empty
        expect(@config.published_entries).to be_empty
        expect(@config.published_assets).to be_empty
        expect(@config.space_id).to eq 'ip17s12q0ek4'
      end
    end
  end
end
