require 'fluent/output'
require 'google/cloud/monitoring/v3/metric_service_api'

module Fluent
  class StackdriverOutput < BufferedOutput
    Fluent::Plugin.register_output('stackdriver', self)

    config_param :project, :string
    config_section :custom_metrics, required: true, multi: false do
      config_param :type, :string
      config_param :metric_kind, :enum, list: [:GAUGE, :DELTA, :CUMULATIVE]
      config_param :value_type, :enum, list: [:BOOL, :INT64, :DOUBLE, :STRING, :DISTRIBUTION, :MONEY]
    end

    def configure(conf)
      super
      @project_name = Google::Cloud::Monitoring::V3::MetricServiceApi.project_path @project
      @metric_name = Google::Cloud::Monitoring::V3::MetricServiceApi.metric_descriptor_path @project, @custom_metrics.type
    end

    def start
      super

      @metric_service_api = Google::Cloud::Monitoring::V3::MetricServiceApi.new

      metric_descriptor = @metric_service_api.get_metric_descriptor(@metric_name)
      if metric_descriptor.is_a? Google::Api::MetricDescriptor
        @metric_descriptor = metric_descriptor
        log.info "succeed to get metric descripter:#{@metric_name}"
      else
        metric_descriptor = Google::Api::MetricDescriptor.new
        metric_descriptor.type = @custom_metrics.type
        metric_descriptor.metric_kind = @custom_metrics.metric_kind
        metric_descriptor.value_type = @custom_metrics.value_type
        @metric_descriptor = @metric_service_api.create_metric_descriptor(@project_name, metric_descriptor)
        log.info "succeed to create metric descripter:#{@metric_name}"
      end
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |tag, time, record|

      end
    end
  end
end
