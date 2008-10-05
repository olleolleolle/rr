module RR
  module DoubleDefinitions
    class Builder #:nodoc:
      attr_reader :creator, :subject, :method_name, :args, :handler, :definition, :verification_strategy, :implementation_strategy
      include Errors
      include Space::Reader

      def initialize(creator)
        @creator = creator
        @using_instance_of_strategy = nil
        @verification_strategy = nil
        @implementation_strategy = Strategies::Implementation::Reimplementation.new
      end

      def build(subject, method_name, args, handler)
        @subject, @method_name, @args, @handler = subject, method_name, args, handler
        @definition = DoubleDefinition.new(creator, subject)
        create_double
        verify_strategy
        verification_strategy.call(definition, args, handler)
        implementation_strategy.call(definition, args, handler)
        definition
      end

      def verification_strategy=(verification_strategy)
        verify_no_verification_strategy
        verify_not_proxy_and_dont_allow(verification_strategy, implementation_strategy)
        @verification_strategy = verification_strategy
        verification_strategy
      end

      def implementation_strategy=(implementation_strategy)
        verify_not_proxy_and_dont_allow(verification_strategy, implementation_strategy)
        @implementation_strategy = implementation_strategy
      end

      def use_instance_of_strategy
        @using_instance_of_strategy = true
      end

      def using_instance_of_strategy?
        !!@using_instance_of_strategy
      end

      protected
      def create_double
        if using_instance_of_strategy?
          create_doubles_for_instances_of_subject(method_name)
        else
          create_double_for_subject(method_name)
        end
      end

      def create_double_for_subject(method_name)
        double_injection = space.double_injection(subject, method_name)
        Double.new(double_injection, definition)
      end

      def create_doubles_for_instances_of_subject(instance_method_name)
        class_handler = lambda do |return_value|
          double_injection = space.double_injection(return_value, instance_method_name)
          Double.new(double_injection, definition)
          return_value
        end

        instance_of_subject_builder = Builder.new(creator)
        instance_of_subject_builder.verification_strategy = Strategies::Verification::Stub.new
        instance_of_subject_builder.implementation_strategy = Strategies::Implementation::Proxy.new
        instance_of_subject_builder.build(subject, :new, [], class_handler)
      end

      def verify_no_verification_strategy
        strategy_already_defined_error if verification_strategy
      end

      def strategy_already_defined_error
        raise(
          DoubleDefinitionError,
          "This Double already has a #{verification_strategy.name} strategy"
        )
      end

      def verify_not_proxy_and_dont_allow(verification_strategy, implementation_strategy)
        proxy_when_dont_allow_error if
          verification_strategy.is_a?(Strategies::Verification::DontAllow) &&
          implementation_strategy.is_a?(Strategies::Implementation::Proxy)
      end

      def proxy_when_dont_allow_error
        raise(
          DoubleDefinitionError,
          "Doubles cannot be proxied when using dont_allow strategy"
        )
      end

      def verify_strategy
        no_strategy_error unless verification_strategy
      end

      def no_strategy_error
        raise(
          DoubleDefinitionError,
          "This Double has no strategy"
        )
      end
    end
  end
end