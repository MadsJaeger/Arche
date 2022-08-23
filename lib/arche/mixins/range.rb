# frozen_string_literal: true

module Arche
  module Mixins
    ##
    # Defineng methods :range and :in_range?. Usefull mixin for ensuring that
    # the clients does not try to access data outside the shape of the
    # data_frame, thus allowing raiseing IndexError when asked index is out of
    # range.
    module Range
      ##
      # From 0..(size-1) of the enumerable
      def range
        0..(size - 1)
      end

      ##
      # Expects integer, array of integers, or a range. If any of the values
      # are outside renge or its negative range false is returned.
      def in_range?(*args)
        if args.size == 0
          return true

        elsif (args.size == 1) && args[0].respond_to?(:to_i)
          min, max = [args[0], args[0]]

        elsif (args.size == 1) && args[0].respond_to?(:minmax)
          min, max = Arche.bound_range(args[0], size - 1).minmax

        else
          begin
            min, max = args.minmax
          rescue ArgumentError
            ranges, ints = args.partition { |item| item.respond_to?(:minmax) }
            out = ints.minmax.compact
            out += ranges.map { |range| Arche.bound_range(range, size - 1).minmax }.flatten.minmax
            min, max = out.minmax
          end
        end

        (min >= -size) && (max <= (size - 1))
      end

      ##
      # Opposite of in_range?
      def out_of_range?(index)
        !in_range?(index)
      end

      private

      def raise_index_error(index)
        raise IndexError, "Out of range index '#{index}', should be within #{range}"
      end
    end
  end
end
