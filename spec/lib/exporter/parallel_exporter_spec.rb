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

    end
  end
end
