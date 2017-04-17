require_relative '../test_helper'

class StackdriverMonitoringOutputTest < Test::Unit::TestCase
  CONFIG = %[
    project project-test
    <custom_metrics>
      key test_key
      type custom.googleapis.com/hoge_type
      metric_kind GAUGE
      value_type INT64
    </custom_metrics>
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::StackdriverMonitoringOutput).configure(conf)
  end

  setup do
    Fluent::Test.setup
  end

  sub_test_case 'configure' do
    test 'values are configured' do
      d = create_driver

      assert_equal('project-test', d.instance.project)
      assert_equal('test_key', d.instance.custom_metrics.key)
      assert_equal('custom.googleapis.com/hoge_type', d.instance.custom_metrics.type)
      assert_equal(:GAUGE, d.instance.custom_metrics.metric_kind)
      assert_equal(:INT64, d.instance.custom_metrics.value_type)
      assert_equal(0, d.instance.custom_metrics.time_interval)
    end

    test 'custom_metrics.type must start with custom.googleapis.com' do
      assert_raises Fluent::ConfigError do
        create_driver(%[
          project project-test
          <custom_metrics>
            key test_key
            type invalid_type
            metric_kind GAUGE
            value_type INT64
          </custom_metrics>
        ])
      end
    end

    test 'time_interval must be greater than 0 if metric_kind is set to CUMULATIVE' do
      assert_raises Fluent::ConfigError do
        create_driver(%[
          project project-test
          <custom_metrics>
            key test_key
            type invalid_type
            metric_kind CUMULATIVE
            value_type INT64
            time_interval 0s
          </custom_metrics>
        ])
      end
    end

    test 'custom metric does not support BOOL value type if metric_kind is set to CUMULATIVE' do
      assert_raises Fluent::ConfigError do
        create_driver(%[
          project project-test
          <custom_metrics>
            key test_key
            type invalid_type
            metric_kind CUMULATIVE
            value_type BOOL
          </custom_metrics>
        ])
      end
    end
  end

  sub_test_case 'write' do
    setup do
      @client = mock!
      @client.start.once
      stub(Fluent::StackdriverMonitoring::Writer).new(anything, anything, anything).once { @client }
    end

    test 'basic data' do
      now = Time.now.to_i
      @client.write(now, now, 1).once

      d = create_driver
      d.emit({'test_key' => 1}, now)
      d.run
    end

    test 'data with time_interval' do
      now = Time.now.to_i
      @client.write(now - 10, now, 1).once

      d = create_driver(%[
        project project-test
        <custom_metrics>
          key test_key
          type custom.googleapis.com/hoge_type
          metric_kind GAUGE
          value_type INT64
          time_interval 10s
        </custom_metrics>
      ])
      d.emit({'test_key' => 1}, now)
      d.run
    end
  end
end
