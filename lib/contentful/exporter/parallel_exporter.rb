require_relative 'data_organizer'
require 'contentful/management'
require 'csv'
require 'fileutils'
require 'yaml'
require 'pp'
require 'api_cache'
require 'open-uri'

module Contentful
  module Exporter
    class ParallelExporter

      Encoding.default_external = 'utf-8'

      attr_reader :space, :config, :logger, :data_organizer
      attr_accessor :content_type

      def initialize(settings)
        @config = settings
        @logger = Logger.new(STDOUT)
        @data_organizer = DataOrganizer.new(@config)
        Contentful::Management::Client.new(config.config['access_token'], default_locale: config.config['default_locale'] || 'en-US')
        initialize_space
      end

      def initialize_space
        @space = Contentful::Management::Space.find(config.config['space_id'])
      end

      def export_content_types
        @space.content_types.all.each { |ct| export_content_type(ct) }
      end

      def export_data
        export_content_types
        export_entries
        export_assets
      end

      def test_credentials
        spaces = Contentful::Management::Space.all
        if spaces.is_a? Contentful::Management::Array
          logger.info 'Contentful Management API credentials: OK'
        end
      rescue NoMethodError => _error
        logger.info 'Contentful Management API credentials: INVALID (check README)'
      end

      def export_entries
        @space.entries.all.each do |entry|
          export_entry(entry)
        end
      end

      def export_assets
        create_directory(File.join(@config.assets_dir, 'files'))
        @space.assets.all.each do |asset|
          export_asset(asset)
        end
      end

      def export_asset(asset)
        logger.info "export asset - #{asset.sys[:id]}"
        asset_title = asset.sys[:id]
        create_asset_file(asset_title, asset)
        create_asset_json_file(asset_title, asset)
      end

      def create_asset_json_file(asset_title, asset)
        asset_params = {
          :id => asset.sys[:id],
          :title => asset.fields[:title],
          :description => asset.fields[:description],
        }
        asset_json_path = File.join(@config.assets_dir, asset.sys[:id] + '.json')
        File.open(asset_json_path, 'w') do |file|
          file.write(JSON.pretty_generate(asset_params))
        end
      end

      def create_asset_file(asset_title, asset)
        dirname = @config.assets_dir
        asset_path = File.join(dirname, 'files', asset_title)
        open('http:' + asset.fields[:file].properties[:url]) {|f|
          File.open(asset_path, 'wb') do |file|
            file.puts f.read
          end
        }
      end

      private

      def export_content_type(content_type)
        logger.info "export content type - #{content_type.sys[:id]}"
        dirname = @config.collections_dir
        create_directory(dirname)
        ct_path = File.join(dirname, content_type.properties[:name] + '.json')
        ct_file = File.open(ct_path, 'w')
        ct_data = create_content_type(content_type)
        ct_json = JSON.pretty_generate(ct_data)
        ct_file.write(ct_json)
      end

      def create_content_type(content_type)
        return {
          :id => content_type.sys[:id],
          :name => content_type.properties[:name],
          :description => content_type.properties[:properties],
          :displayField => '',
          :fields => create_content_type_fields(content_type),
        }
      end

      def get_id(params)
        File.basename(params['id'] || params['url'])
      end

      def create_content_type_fields(content_type)
        return content_type.properties[:fields].each_with_object([]) do |field, fields|
          fields << create_field_params(field)
        end
      end

      def export_entry(entry)
        logger.info "export entry - #{entry.sys[:id]}"
        entry_params = {:id => entry.sys[:id]}
        entry_params.merge!(create_entry_parameters(entry))
        content_type_id = entry.sys[:contentType].sys[:id]
        content_type = content_type(content_type_id, @space.sys[:id])

        dirname = File.join(@config.entries_dir, content_type.properties[:name])
        create_directory(dirname)

        entry_path = File.join(dirname, entry_params[:id] + '.json')
        entry_file = File.open(entry_path, 'w')
        entry_json = JSON.pretty_generate(entry_params)
        entry_file.write(entry_json)
      end

      def create_entry_parameters(entry)
        entry.fields.each_with_object({}) do |(attr, value), entry_params|
          entry_param = if value.is_a? Hash
                          parse_attributes_from_hash(value)
                        elsif value.is_a? Array
                          parse_attributes_from_array(value)
                        else
                          value
                        end
          entry_params[attr.to_sym] = entry_param
        end
      end

      def parse_attributes_from_hash(params)
        return {
          :id => params['sys']['id'],
          :type => 'Link',
        }
      end

      def parse_attributes_from_array(params)
        params.each_with_object([]) do |attr, array_attributes|
          if attr['sys'].present?
            array_attributes << {
              :id => attr['sys']['id'],
              :type => 'Link',
            }
          else
            array_attributes << attr
          end
        end
      end

      def content_type(content_type_id, space_id)
        @content_type = APICache.get("content_type_#{content_type_id}", :period => -5) do
          Contentful::Management::ContentType.find(space_id, content_type_id)
        end
      end

      def create_field_params(field)
        field_params = {
          :id => field.properties[:id],
          :name => field.properties[:name],
          :required => field.properties[:required],
        }
        field_params.merge!(additional_field_params(field))
        #logger.info "Creating field: #{field_params[:type]}"
        return field_params
      end

      def create_content_type_field(field_params)
        Contentful::Management::Field.new.tap do |field|
          field.id = field_params[:id]
          field.name = field_params[:name]
          field.type = field_params[:type]
          field.link_type = field_params[:link_type]
          field.required = field_params[:required]
          field.items = field_params[:items]
        end
      end

      def additional_field_params(field)
        field_type = field.properties[:type]
        if field_type == 'Entry' || field_type == 'Asset'
          {type: 'Link', link_type: field_type}
        elsif field_type == 'Array'
          {type: 'Array', items: create_array_field(field)}
        else
          {type: field_type}
        end
      end

      def create_array_field(params)
        json = {
          :type => params.properties[:items].properties[:type] || 'Link',
          :link_type => params.properties[:items].properties[:linkType],
        }
        return json
      end

      def create_directory(path)
        FileUtils.mkdir_p(path) unless File.directory?(path)
      end

    end
  end
end
