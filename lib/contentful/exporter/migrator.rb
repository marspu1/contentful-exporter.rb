require_relative 'parallel_exporter'
require_relative 'configuration'

module Contentful
  module Exporter
    class Migrator

      attr_reader :exporter, :converter, :config, :json_validator

      def initialize(settings)
        @config = Configuration.new(settings)
        @exporter = ParallelExporter.new(@config)
      end

      def run(action, options = {})
        case action.to_s
          when '--export'
            exporter.export_data(options[:threads])
          when '--export-content-types'
            exporter.export_content_types
          when '--export-assets'
            exporter.export_assets
          when '--export-entries'
            exporter.export_entries
          when '--test-credentials'
            exporter.test_credentials
        end
      end
    end
  end
end
