# frozen_string_literal: true

module Arche
  ##
  # Individual column contained by Columns class. A column is instantiated within
  # an array acts mostly like an array.
  # Enumerbale or subclass of Array?
  # When enumerable we need to constantly cast into own class
  # when array we constantly need to worry about mutability
  class Column
    extend Forwardable
    extend Mixins::Statistics
    include Mixins::Range

    ##
    # Initializes with a Columns instance and array -> @data. If data_kind_of_float?
    # nil will be replaced with NaN.
    def initialize(columns, array) # :doc:
      @columns = columns
      @data = array.dup
      replace_nil! if data_kind_of_float?
      yield self if block_given?
    end

    ##
    # Delegates with method_missing to @data
    def method_missing(meth, *args, **kwargs, &block)
      return @data.send(meth, *args, **kwargs, &block) if @data.respond_to?(meth)

      super(meth, *args, **kwargs, &block)
    end

    def respond_to_missing?(meth)
      @data.respond_to?(meth)
    end

    def_delegators :@data,
                   *%i(& all? any? count each each_index each_with_index empty?
                       fetch find find_index first group_by include? index inject
                       last length map map! max min minmax reduce reverse include?
                       reverse_each rotate sample size |)

    delegate_statistic_to :compact

    ##
    # Zips its data with another array.
    def zip(other)
      @data.zip(other.to_a)
    end

    alias nrow size
    ####

    ##
    # Returning alements at indexes, and raises IndexError when out of range.
    # Arguments may be composed as follows:
    #
    #   [index] => calls fetch(index)
    #   [range] => super[range]
    #   [start, length] => calls take from from start
    #   [*indexes_and_ranges] => values_at(*indexes_and_ranges)
    #
    def [](*args)
      if (args.size == 1) && args[0].is_a?(Integer)
        fetch(args[0])
      elsif (args.size == 1) && args[0].is_a?(Range)
        raise_index_error(args[0]) unless in_range?(args[0])
        @data[args[0]]
      elsif (args.size == 1) && args[0].is_a?(Hash)
        start  = args[0].fetch(:start).to_i
        length = args[0].fetch(:length).to_i
        raise_index_error(start) unless in_range?(start)
        @data[start..].take(length)
      else
        values_at(*args)
      end
    end

    ##
    # Set value at index, raises index error when out of range
    def []=(index, value)
      raise_index_error(index) unless in_range?(*index)

      if index.respond_to?(:each)
        set = Arche.index_set_of(*index, bound: size - 1)
        value = [value] * set.size unless value.respond_to?(:each)
        raise ArgumentError, "incompatible dimensions of index(#{set.size}) and value(#{value.size})" if value.size != set.size

        set.zip(value).each do |index,val|
          @data[index] = val
        end
      else
        @data[index] = value
      end
    end

    ##
    # Similar to Array#values_at but raises IndexError when any of the indices are out of range
    def values_at(*indexes)
      raise_index_error('*indexes') unless in_range?(*indexes)

      @data.values_at(*indexes)
    end

    ##
    # :method: +
    # Adds another equally dimensioned array onto own data, returns a new array
    # :method: add!
    # Mutating version of +

    # :method: -
    # Subtracts another equally dimensioned array from own data, returns a new array

    # :method: subtract!
    # Mutating version of -

    # :method: *
    # Multiplies another equally dimensioned array onto own data, returns a new array

    # :method: mult!
    # Mutating version of *

    # :method: /
    # Divides with another equally dimensioned array, returns a new array

    # :method: divide!
    # Mutating version of /

    # :method: **
    # Computes the power with another equally dimensioned array, returns a new array

    # :method: power!
    # Mutating version of **

    # :method: %
    # Takes the modulo to another equally dimensioned array, returns a new array

    # :method: modulo!
    # Mutating version of %
    {
      :+ => 'add!',
      :- => 'subtract!',
      :* => 'mult!',
      :/ => 'divide!',
      :** => 'power!',
      :% => 'modulo!'
    }.each do |key, banged|
      define_method(key) do |col|
        zip_map(col, &key)
      end

      define_method(banged) do |col|
        @data = send(key, col)
        self
      end
    end

    ##
    # Zips its data to other column or array, and yields(row, other). If the other
    # do not respond to :each the column is zipped to the other n times. This is
    # usefull for adding, subtracting, etc.
    #
    #   col = Column.new(@columns, [1,2,3])
    #   col.zip_map(1, &:+) => [2,3,4]
    #   col.zip_map(col, &:+) => [2,4,6]
    def zip_map(col, &block)
      block = ->(a, b) { a.send(block, b) } if block.is_a?(Symbol)
      if col.respond_to? :each
        zip(col).map { |a, b| block.call(a, b) }
      else
        map { |v| block.call(v, col) }
      end
    end

    ##
    # \Returns an array of rounded values
    def round(n)
      map { |v| v.round(n) }
    end

    ##
    # Rounds each value, mutates @data
    def round!(n)
      @data.map! { |v| v.round(n) }
      self
    end

    ##
    # Returns an array of same size as column. Takes argument init = 0, as the
    # starting value for the cumulative action. The block may either be a symbol
    # or a block taking arguments |sum, value|
    #
    #   cumulative(&:+) => returns cumulative sum
    #   cumulative('') { |sum, v|  sum + v.to_s} => creates ever longer strings
    #   cumulative(1, &:*) => Returns cumulative product
    def cumulative(init = 0, &block)
      if block.is_a?(Symbol)
        map { |v| init = init.send(block, v) }
      else
        map { |v| init = block.call(init, v) }
      end
    end

    ##
    # As cumulative but repalces @data
    def cumulative!(init = 0, &block)
      @data = cumulative(init, &block)
    end

    ##
    # Lags @data by step, and places value_empty: in place of non-lagged values.
    #
    #   [1,2,3].lag(1)
    #   => [nil,1,2]
    #
    #   [1,2,3].lag(-1)
    #   => [2,3,nil]
    def lag(step = 1, value_empty: nil)
      raise_index_error(step) if step.abs > size

      if step.positive?
        [value_empty] * step + @data[0..(- step - 1)]
      elsif step.negative?
        @data[step.abs..] + [value_empty] * step.abs
      else
        to_a
      end
    end

    ##
    # Like :lag but mutates @data
    def lag!(step = 1)
      @data = lag(step)
      self
    end

    ##
    # Takes the difference to lagged value
    def diff(step = 1)
      self - lag(step, value_empty: Float::NAN)
    end

    ##
    # Like :diff but mutates @data
    def diff!(step = 1)
      @data = diff(step)
      self
    end

    # :method: to_c
    # @data.map(&:to_c), to complex

    # :method: to_c!
    # @data.map!(&:to_c)

    # :method: to_d
    # @data.map(&:to_d), to decimal

    # :method: to_d!
    # @data.map!(&:to_d)

    # :method: to_f
    # @data.map(&:to_f), to float

    # :method: to_f!
    # @data.map!(&:to_f)

    # :method: to_i
    # @data.map(&:to_i), to integer

    # :method: to_i!
    # @data.map!(&:to_i)

    # :method: to_s
    # @data.map(&:to_s), to string

    # :method: to_s!
    # @data.map!(&:to_s)

    # :method: abs
    # @data.map(&:abs), absolute

    # :method: abs!
    # @data.map!(&:abs)
    %i(to_c to_d to_f to_i to_r to_s abs).each do |converter|
      define_method(converter) do
        map(&converter)
      end

      define_method("#{converter}!") do
        @data = send(converter)
      end
    end

    ##
    # Returns a copy of its @data
    def to_a
      @data.dup
    end

    ##
    # Replace nil values with replacement, mutating
    def replace_nil!(replacement = Float::NAN)
      map! { |v| v.nil? ? replacement : v }
      self
    end

    ##
    # Replace nil values with replacement
    def replace_nil(replacement = Float::NAN)
      map { |v| v.nil? ? replacement : v }
    end

    ##
    # Replace NaN values with replacement, mutating
    def replace_nan!(replacement = nil)
      map! { |v| v.nan? ? replacement : v }
      self
    end

    ##
    # Replace NaN values with replacement
    def replace_nan(replacement = nil)
      map { |v| v.nan? ? replacement : v }
    end

    ##
    # For each key word argument a replacements ar made from key to value.
    #
    #   [1,2].replace_values **{1 => 2, 2 => 1}
    #   => [2,1]
    def replace_values(**kwargs)
      make_replacements(@data.dup, **kwargs)
    end

    ##
    # Mutating verison of :repleace_values
    def replace_values!(**kwargs)
      make_replacements(self, **kwargs)
    end

    ##
    # Replaces @data with new array
    def replace!(new_array)
      raise ArgumentError, 'Column can not be replaced with a new array of different size' if new_array.size != size

      @data = new_array
    end

    ##
    # Unmutable removal of nil and NaN
    def compact
      @data.compact.reject(&:nan?)
    end

    ##
    # Mutable removal of all nil and NaN values, removes elements at same indices
    # on sibling columns
    def compact!
      reject!(&:nil?)
      reject!(&:nan?)
      self
    end

    ##
    # Will reduce sibling columns to same indices (rows) selected.
    def select!(&block)
      subset_rows_at!(*select_indexes(&block))
      self
    end

    ##
    # Will reject sibling columns to same indices (rows) rejected.
    def reject!(&block)
      remove_rows_at!(*select_indexes(&block))
      self
    end

    ##
    # Find all indexes matching value
    def find_indexes(value = nil, &block)
      if block_given?
        select_indexes(&block)
      elsif value.nan?
        select_indexes(&:nan?)
      else
        select_indexes { |val| val == value }
      end
    end

    ##
    # Selects all indices given a block
    def select_indexes(&block)
      each_with_index.select { |val, _index| block.call(val) }.map(&:last)
    end

    ##
    # Delete all elements equal to argument, and removes all rows on same indices on sibling columns
    def delete(arg)
      remove_rows_at!(*find_indexes(arg))
      self
    end

    ##
    # Deletes given gcondition, and on all sibling columns at same indices
    alias delete_if reject!

    ##
    # Remove n last rows
    def pop(count = 1)
      return unless size.positive? && count.positive?

      range = [(size - count), 0].max..(size - 1)
      remove_rows_at!(*range.to_a)
    end

    ##
    # Mutates the column removing all duplicated entries and on sibling columsn as
    # well
    def uniq!
      unique_entries = []
      indices = select_indexes do |value|
        if unique_entries.include? value
          false
        else
          unique_entries << value
          true
        end
      end
      subset_rows_at!(*indices)
      self
    end

    ##
    # Subsets to all rows on given indexes and on sibling columns as well. A check
    # is made wheter or not alle indices are in range raising index error if
    # indexes are out of range
    def select_rows_at!(*indices)
      raise_index_error(index) unless in_range?(*indices)

      subset_rows_at!(*indices)
      self
    end

    ##
    # Removes alle rows on given indexes and on sibling columns as well. A check
    # is made wheter or not alle indices are in range raising index error if
    # indexes are out of range
    def delete_rows_at!(*indices)
      raise_index_error(index) unless in_range?(*indices)

      remove_rows_at!(*indices)
      self
    end

    ##
    # Delete all rows at given indices, and on sibling columns
    alias delete_at delete_rows_at!

    ##
    # Rearanges data given a sorting block. Yields an array of all non-nil items
    # and their original index, and must be returned with an array that respond to
    # last, i.e. holds the original index.
    def rearange(nil_first: true, asc: true, mutate: true)
      grouped = zip(range).group_by do |value, _index|
        value.nil? || value.nan?
      end
      grouped[true] ||= []
      grouped[false] ||= []

      indices = yield(grouped[false]).map(&:last)
      indices.reverse! unless asc
      fun = nil_first ? :prepend : :append
      indices.send(fun, *grouped[true].map(&:last))

      if mutate
        subset_rows_at!(*indices)
        self
      else
        values_at(*indices)
      end
    end

    ##
    # Sorts by <=> method or whtever given by the block, and applies on all
    # columns
    def sort!(**kwargs, &block)
      rearange(**kwargs) do |non_nil_itmes|
        non_nil_itmes.sort(&block)
      end
    end

    ##
    # Leverages nil actions from rearange but do not mutate its order
    def sort(**kwargs, &block)
      rearange(**kwargs.merge(mutate: false)) do |non_nil_itmes|
        non_nil_itmes.sort(&block)
      end
    end

    ##
    # sort_by whatever given by the blocknd and applies on all columns
    def sort_by!(**kwargs, &block)
      rearange(**kwargs) do |non_nil_itmes|
        non_nil_itmes.sort_by { |value, _index| block.call(value) }
      end
    end

    ##
    # Leverages nil actions from rearange but do not mutate its order
    def sort_by(**kwargs, &block)
      rearange(**kwargs.merge(mutate: false)) do |non_nil_itmes|
        non_nil_itmes.sort_by { |value, _index| block.call(value) }
      end
    end

    ##
    # Reverse the order of all columns
    def reverse!
      @columns.each do |_name, col|
        col.data.reverse!
      end
      self
    end


    ##
    # Rowvise comparinson. Comparing nan to nan will return true.
    def ==(other)
      return false unless size == other.size

      zip(other).all? do |this, ext|
        (this == ext) || (this.nan? && ext.nan?)
      end
    end

    def !=(other)
      return true unless size != other.size

      zip(other).any? do |this, ext|
        (this != ext)
      end
    end

    ##
    # Class of first non nil and non NaN value
    def data_type
      find(&:itself)&.class
    end

    ##
    # Is the first non nil element a a Numeric but not an integer.
    def data_kind_of_float?
      find(&:itself).is_a?(Numeric) && !find(&:itself).is_a?(Integer)
    end

    def inspect(n = 10)
      inside = if nrow > n
                 @data[0..(n-1)].inspect[0..-2] + ', ...]'
               else
                 @data.inspect
               end
      "#<Arche::Column #{inside}>"
    end

    protected

    ##
    # Array of observations in column, i.e. storage.
    attr_accessor :data

    def compacted(yes=true)
      yes ? compact : @data
    end

    def make_replacements(data, **args)
      args.each do |old_value, new_value|
        data.map! { |v| v == old_value ? new_value : v }
      end
      data
    end

    ##
    # Removing all elements on indices
    def delete_at_indexes!(*indices)
      indices = Arche.index_set_of(*indices, bound: size - 1)
      @data.delete_if.with_index { |_, index| indices.include? index }
    end

    ##
    # Faster version of select_rows_at! as no check on the indices are made,
    # nor are ranges in the array of integers allowed. Can be uses to rearange
    def subset_rows_at!(*indices)
      @columns.each do |_name, col|
        col.data = col.data.values_at(*indices)
      end
    end

    ##
    # Faster version of delete_rows_at! as no check on the indices are made,
    # nor are ranges in the array of integers allowed.
    def remove_rows_at!(*indices)
      @columns.each do |_name, col|
        col.delete_at_indexes!(*indices)
      end
    end
  end
end
