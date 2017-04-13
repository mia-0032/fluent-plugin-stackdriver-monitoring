# fluent-plugin-stackdriver-monitoring

[Stackdriver Monitoring](https://cloud.google.com/monitoring/) custom metrics output plugin for [Fluentd](http://www.fluentd.org/)

## Installation

```shell
$ gem install fluent-plugin-stackdriver-monitoring
```

## Authentication

See [google-cloud-monitoring gem document](https://github.com/GoogleCloudPlatform/google-cloud-ruby/tree/master/google-cloud-monitoring#setup-authentication).

## Configuration

Sample configuration is below.

```
<match your.tag>
  @type stackdriver_monitoring
  project {{PROJECT_NAME}}

  <custom_metrics>
    key {{KEY_NAME}}
    type custom.googleapis.com/{{METRICS_NAME}}
    metric_kind GAUGE
    value_type INT64
  </custom_metrics>

  flush_interval 1s  # must be 1(sec) or above
</match>
```

- project (string, required)
  - Set your Stackdriver project id.
- custom_metrics
  - key (string, required)
    - Specify field name in your log to send to Stackdriver.
  - type (string, required)
    - Set name of descriptor. It must start with `custom.googleapis.com/`.
  - metric_kind(enum, required)
    - See [metric kind](https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.metricDescriptors#MetricKind).
    - You can specify `GAUGE` or `CUMULATIVE`.
    - Custom metric does not support `DELTA`. See [here](https://cloud.google.com/monitoring/api/v3/metrics?hl=en#metric-kinds).
  - value_type(enum, required)
    - See [value type](https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.metricDescriptors#valuetype).
    - You can specify `BOOL`, `INT64` or `DOUBLE` if metric_kind is `GAUGE`. And `INT64` or `DOUBLE` can be specified if metric_kind is `CUMULATIVE`.
    - Custom metric does not support `MONEY` and `STRING`. See [here](https://cloud.google.com/monitoring/api/v3/metrics?hl=en#metric-kinds).
  - time_interval(time, optional)
    - This param is used as the difference between start time and end time.
    - It must be greater than 0s if metric_kind is set to `CUMULATIVE`.

## TODO

- Add test!
- Support Unit and Monitored Resource in custom_metrics.
