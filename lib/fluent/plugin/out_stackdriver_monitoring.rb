require 'fluent/output'
require 'google/api/metric_pb'
require 'google/cloud/monitoring/v3/metric_service_client'
require 'google/protobuf/repeated_field'
require 'google/protobuf/timestamp_pb'

module Fluent
  class StackdriverMonitoringOutput < BufferedOutput
    Fluent::Plugin.register_output('stackdriver_monitoring', self)

    config_param :project, :string
    config_section :custom_metrics, required: true, multi: false do
      config_param :key, :string
      config_param :type, :string
      config_param :metric_kind, :enum, list: [:GAUGE, :CUMULATIVE]
      config_param :value_type, :enum, list: [:BOOL, :INT64, :DOUBLE] # todo: implement :DISTRIBUTION
      config_param :time_interval, :time, default: 0
    end

    TYPE_PREFIX = 'custom.googleapis.com/'.freeze

    def configure(conf)
      super

      unless is_custom_metric? @custom_metrics.type
        raise Fluent::ConfigError.new "custom_metrics.type must start with \"#{TYPE_PREFIX}\""
      end

      if @custom_metrics.metric_kind == :CUMULATIVE
        if @custom_metrics.time_interval == 0
          raise Fluent::ConfigError.new 'time_interval must be greater than 0 if metric_kind is set to CUMULATIVE'
        end
        if @custom_metrics.value_type == :BOOL
          raise Fluent::ConfigError.new 'custom metric does not support BOOL value type if metric_kind is set to CUMULATIVE'
        end
      end

      @project_name = Google::Cloud::Monitoring::V3::MetricServiceClient.project_path @project
      @metric_name = Google::Cloud::Monitoring::V3::MetricServiceClient.metric_descriptor_path @project, @custom_metrics.type
    end

    def start
      super

      @metric_service_client = Google::Cloud::Monitoring::V3::MetricServiceClient.new
      @metric_descriptor = create_metric_descriptor
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |tag, time, record|
        time_series = create_time_series
        value = record[@custom_metrics.key]

        point = Google::Monitoring::V3::Point.new
        point.interval = create_time_interval time, @custom_metrics.time_interval
        point.value = create_typed_value value
        time_series.points.push point

        log.debug "Create time series", time: Time.at(time).to_s, value: value, metric_name: @metric_name
        # Only one point can be written per TimeSeries per request.
        @metric_service_client.create_time_series @project_name, [time_series]
      end
    end

    private
    def is_custom_metric?(metric_type)
      metric_type.start_with? TYPE_PREFIX
    end

    def create_metric_descriptor
      begin
        metric_descriptor = @metric_service_client.get_metric_descriptor(@metric_name)
        log.info "Succeed to get metric descripter", metric_name: @metric_name
        return metric_descriptor
      rescue Google::Gax::RetryError
        log.info "Failed to get metric descripter", metric_name: @metric_name
      end

      metric_descriptor = Google::Api::MetricDescriptor.new
      metric_descriptor.type = @custom_metrics.type
      metric_descriptor.metric_kind = @custom_metrics.metric_kind
      metric_descriptor.value_type = @custom_metrics.value_type
      metric_descriptor = @metric_service_client.create_metric_descriptor(@project_name, metric_descriptor)
      log.info "Succeed to create metric descripter", metric_name: @metric_name

      metric_descriptor
    end

    def create_time_series
      time_series = Google::Monitoring::V3::TimeSeries.new

      metric = Google::Api::Metric.new
      metric.type = @metric_descriptor.type
      time_series.metric = metric

      time_series.metric_kind = @metric_descriptor.metric_kind
      time_series.value_type = @metric_descriptor.value_type

      time_series
    end

    def create_time_interval(time, interval)
      time_interval = Google::Monitoring::V3::TimeInterval.new
      time_interval.start_time = Google::Protobuf::Timestamp.new seconds: (time - interval)
      time_interval.end_time = Google::Protobuf::Timestamp.new seconds: time

      time_interval
    end

    def create_typed_value(value)
      typed_value = Google::Monitoring::V3::TypedValue.new
      case @metric_descriptor.value_type
      when :BOOL
        typed_value.bool_value = value.to_bool
      when :INT64
        typed_value.int64_value = value.to_i
      when :DOUBLE
        typed_value.double_value = value.to_f
      else
        raise 'Unknown value_type!'
      end

      typed_value
    end
  end
end
