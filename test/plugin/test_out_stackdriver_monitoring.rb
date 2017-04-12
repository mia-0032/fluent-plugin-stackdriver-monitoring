require_relative '../test_helper'

class StackdriverMonitoringOutputTest < Test::Unit::TestCase
  CONFIG = %[
    project project-test
    <custom_metrics>
      key hoge_key
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
      assert_equal('hoge_key', d.instance.custom_metrics.key)
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
            key hoge_key
            type invalid_type
            metric_kind GAUGE
            value_type INT64
          </custom_metrics>
        ])
      end
    end

    test 'time_interval must be greater than 0 if metric_kind is set to DELTA or CUMULATIVE' do
      assert_raises Fluent::ConfigError do
        create_driver(%[
          project project-test
          <custom_metrics>
            key hoge_key
            type invalid_type
            metric_kind DELTA
            value_type INT64
            time_interval 0s
          </custom_metrics>
        ])
      end

      assert_raises Fluent::ConfigError do
        create_driver(%[
          project project-test
          <custom_metrics>
            key hoge_key
            type invalid_type
            metric_kind CUMULATIVE
            value_type INT64
            time_interval 0s
          </custom_metrics>
        ])
      end
    end
  end
end
