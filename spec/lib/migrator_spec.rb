require 'spec_helper'
require './lib/contentful/exporter/migrator'

def clear_space(space_id, access_token)
  require 'contentful/management'
  Contentful::Management::Client.new(access_token, raise_errors: true, logger: Logger.new(STDOUT), log_level: Logger::WARN)
  space = Contentful::Management::Space.find(space_id)

  space.entries.all(limit: 1000).each do |e|
    e.unpublish if e.published?
    e.destroy
    puts "Cleared entry: #{e.id} (#{e.name rescue ''})"
  end

  space.content_types.all.each do |ct|
    ct.deactivate if ct.active?
    ct.destroy
    puts "Cleared content type: #{ct.id} (#{ct.name rescue ''})"
  end

  space.assets.all.each do |a|
    a.unpublish if a.published?
    a.destroy
    puts "Cleared asset: #{a.id} (#{a.name rescue ''})"
  end
end

module Contentful
  module Exporter
    describe Migrator do

      before do
        @settings_file = YAML.load_file('spec/fixtures/settings/settings.yml')
      end

      it 'export all from Contentful' do
        vcr('export') do
          Migrator.new(@settings_file).run('--export')
        end
      end

      it 'create content type json files from contentful structure' do
        vcr('export_content_types') do
          Migrator.new(@settings_file).run('--export-content-types')
        end
      end

      it 'export entires from Contentful with two Threads' do
        vcr('export_entries') do
          allow(FileUtils).to receive(:rm_r)
          Migrator.new(@settings_file).run('--export-entries', threads: 2)
        end
      end

      it 'export an assets from Contentful' do
        vcr('export_assets') do
          Migrator.new(@settings_file).run('--export-assets')
        end
      end

      it 'can import what it exports' do
        require 'contentful/importer/migrator'

        import_settings = {
          'data_dir' => @settings_file['data_dir'],
          'space_id' => @settings_file['import_space_id'],
          'access_token' => @settings_file['import_access_token'],
        }
        importer = Contentful::Importer::Migrator.new(import_settings)

        vcr('export') do
          Migrator.new(@settings_file).run('--export')
        end

        vcr('import') do
          clear_space(@settings_file['import_space_id'], @settings_file['import_access_token'])
          importer.run('--import-content-types', space_id: @settings_file['import_space_id'])
          importer.run('--import-assets')
          importer.run('--publish-assets', threads: 2)
          importer.run('--import', threads: 2)
          importer.run('--publish-entries', threads: 2)
        end
      end

      context 'test credentials' do
        it 'when valid' do
          vcr('valid_credentials') do
            expect_any_instance_of(Logger).to receive(:info).with('Contentful Management API credentials: OK')
            Migrator.new(@settings_file).run('--test-credentials')
          end
        end
        it 'when invalid' do
          vcr('invalid_credentials') do
            expect_any_instance_of(Logger).to receive(:info).with('Contentful Management API credentials: INVALID (check README)')
            @settings_file['access_token'] = 'bad'
            Migrator.new(@settings_file).run('--test-credentials')
          end
        end
      end
    end
  end
end
