# frozen_string_literal: true

require "test_helper"

# Stub a minimal Rails::Railtie so the railtie file can be loaded without
# pulling in all of Rails. The stub captures initializer blocks and supports
# config.after_initialize as a no-op.
unless defined?(Rails::Railtie)
  module Rails
    class Railtie
      class Configuration
        def after_initialize(&block)
          # no-op in test
        end

        def method_missing(_name, *_args, &_block)
          self
        end

        def respond_to_missing?(_name, _include_private = false)
          true
        end
      end

      @initializers = []

      class << self
        attr_reader :initializers

        def initializer(name, _opts = {}, &block)
          @initializers << { name: name, block: block }
        end

        def config
          @config ||= Configuration.new
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@initializers, [])
          subclass.instance_variable_set(:@config, Configuration.new)
        end
      end
    end
  end
end

require_relative "../lib/cmd_log/railtie"

class RailtieTest < Minitest::Test
  def test_railtie_class_is_defined
    assert defined?(CmdLog::Railtie), "expected CmdLog::Railtie to be defined"
  end

  def test_railtie_inherits_from_rails_railtie
    assert CmdLog::Railtie < Rails::Railtie,
           "expected CmdLog::Railtie to inherit from Rails::Railtie"
  end

  def test_registers_initializers
    names = CmdLog::Railtie.initializers.map { |i| i[:name] }

    assert_includes names, "cmd_log.configure"
    assert_includes names, "cmd_log.middleware"
  end
end
