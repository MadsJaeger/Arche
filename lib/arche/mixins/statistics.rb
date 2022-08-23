module Arche
  module Mixins
    ##
    # For computations on an array. All class methods take array as first
    # argument, on which function is to be called. Usage:
    #
    #   array = [1,2,3]
    #   extend Arche::Mixins::Statistics
    #   delegate_statistic_to :array
    #   mean
    #   => 2
    module Statistics
      ##
      # Adds all class methods as instance methods, with :argument as array to
      # delegate statistics onto.
      def delegate_statistic_to(symbol)
        Arche::Mixins::Statistics.methods(false).each do |meth|
          def_statistical_delegator(symbol, meth)
        end
      end

      ##
      # Defining instance method refering to a class method in statistics,
      # with a reference array.
      def def_statistical_delegator(symbol, meth)
        define_method(meth) do |*args, **kwargs, &block|
          arr = send(symbol)
          Arche::Mixins::Statistics.send(meth, arr, *args, **kwargs, &block)
        end
      end

      class << self
        ##
        # Product of all values (reduce(1, :*)), rejectin nil and nan by default.
        def prod(arr)
          arr.reduce(1, :*)
        end

        ##
        # Sum with default rejection of nil and nan
        %i(sum min max minmax).each do |key|
          define_method(key) do |arr|
            arr.send(key)
          end
        end

        ##
        # Average
        def mean(arr)
          return nil if arr.size.zero?

          arr.sum / arr.size.to_f
        end

        ##
        # Variance, sample
        def var(arr)
          return nil if arr.size < 2

          mean = arr.sum / arr.size
          sum  = arr.inject(0) { |accum, i| accum + (i - mean)**2 }
          sum / (arr.size - 1).to_f
        end

        ##
        # Standard deviation, sample
        def std(array)
          svar = var(array)
          return nil unless svar

          Math.sqrt(svar)
        end
      end
    end
  end
end
