require 'spec_helper'
require './lib/contentful/exporter/migrator'

module Contentful
  module Exporter
    describe Migrator do
      before do
        @setting_file = YAML.load_file('spec/fixtures/settings/settings.yml')
      end
      it 'create content type json files from contentful structure' do
        vcr('export_content_types') do
          Migrator.new(@setting_file).run('--export-content-types')
        end
      end

      it 'export entires from Contentful with two Threads' do
        vcr('export_entries') do
          allow(FileUtils).to receive(:rm_r)
          Migrator.new(@setting_file).run('--export-entries', threads: 2)
        end
      end

      it 'export an assets from Contentful' do
        vcr('export_assets') do
          Migrator.new(@setting_file).run('--export-assets')
        end
      end

      it 'export all from Contentful' do
        vcr('export') do
          Migrator.new(@setting_file).run('--export')
        end
      end

      context 'test credentials' do
        it 'when valid' do
          vcr('valid_credentials') do
            expect_any_instance_of(Logger).to receive(:info).with('Contentful Management API credentials: OK')
            Migrator.new(@setting_file).run('--test-credentials')
          end
        end
        it 'when invalid' do
          vcr('invalid_credentials') do
            expect_any_instance_of(Logger).to receive(:info).with('Contentful Management API credentials: INVALID (check README)')
            @setting_file['access_token'] = 'bad'
            Migrator.new(@setting_file).run('--test-credentials')
          end
        end
      end
    end
  end
end
