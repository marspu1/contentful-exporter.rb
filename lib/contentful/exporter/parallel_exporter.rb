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
        @space.entries.all({:limit => 1000}).each do |entry|
          export_entry(entry)
        end
      end

      def export_assets
        create_directory(File.join(@config.assets_dir, 'files'))
        @space.assets.all({:limit => 1000}).each do |asset|
          export_asset(asset)
        end
      end

      def export_asset(asset)
        logger.info "export asset - #{asset.sys[:id]}"

        json_dirname = @config.assets_dir
        num = Dir[json_dirname + '/*'].count
        json_filename = num.to_s + '.json'
        json_filepath = File.join(json_dirname, json_filename)

        create_asset_file(asset)
        create_asset_json_file(json_filepath, asset)
      end

      def create_asset_json_file(filepath, asset)
        asset_params = {
          :id => asset.sys[:id],
          :title => asset.fields[:title],
          :description => asset.fields[:description],
        }
        filename = asset_file_name(asset)
        asset_params[:url] = filename if filename

        File.open(filepath, 'w') do |file|
          file.write(JSON.pretty_generate(asset_params))
        end
      end

      def asset_file_name(asset)
        return nil if !asset.file
        asset.file.properties[:fileName]
      end

      def create_asset_file(asset)
        filename = asset_file_name(asset)
        return if !filename

        dirname = @config.assets_dir
        asset_path = File.join(dirname, 'files', filename)
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
          :displayField => content_type.properties[:displayField],
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

        num = Dir[dirname + '/*'].count
        filename = num.to_s + '.json'

        entry_path = File.join(dirname, filename)
        entry_file = File.open(entry_path, 'w')
        entry_json = JSON.pretty_generate(entry_params)
        entry_file.write(entry_json)
      end

      def create_entry_parameters(entry)
        entry.fields.each_with_object({}) do |(attr, value), entry_params|
          entry_param = if value.is_a? Contentful::Management::Location
                          {
                            :type => 'Location',
                            :lat => value.properties[:lat],
                            :lng => value.properties[:lon]
                          }
                        elsif value.is_a? Hash
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
        attrs = {:id => params['sys']['id']}
        type = params['sys']['linkType']
        if type
          case type
          when 'Asset'
            attrs[:type] = 'File'
          else
            attrs[:type] = 'Link'
          end
        end
        attrs
      end

      def parse_attributes_from_array(params)
        params.each_with_object([]) do |attr, array_attributes|
          if attr.is_a? Hash
            array_attributes << parse_attributes_from_hash(attr)
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
        validations = field_validations(field)
        field_params[:validations] = validations if validations != []
        return field_params
      end

      def field_validations(field)
        if !field.validations.is_a? Array
          []
        else
          field.validations.each_with_object([]) do |validation, validations|
             type, params = validation.properties.find {|k,v| ![nil, "", false].include?(v) and k != :validations}
             validations << {:type => type, :params => params}
          end
        end
      end

      def additional_field_params(field)
        field_type = field.properties[:type]
        if field_type == 'Link'
          {:link => 'Link', :type => field.properties[:linkType]}
        elsif field_type == 'Array'
          params = {:type => 'Array'}
          params[:link] = field.properties[:items].properties[:type] || 'Link'
          if params[:link] == 'Link'
            params[:link_type] = field.properties[:items].properties[:linkType]
          end
          params
        else
          {:type => field_type}
        end
      end

      def create_directory(path)
        FileUtils.mkdir_p(path) unless File.directory?(path)
      end

    end
  end
end
