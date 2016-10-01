require 'fluent/output'

module Fluent
  class StackdriverOutput < BufferedOutput
    Fluent::Plugin.register_output('stackdriver', self)
  end
end
