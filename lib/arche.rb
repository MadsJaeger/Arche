# frozen_string_literal: true

require 'set'
require 'forwardable'
require 'bigdecimal'
require 'bigdecimal/util'
require 'json'
require 'yaml'

require_relative 'arche/version'
require_relative 'arche/mixins'
require_relative 'arche/object'
require_relative 'arche/column'
require_relative 'arche/columns'
require_relative 'arche/row'
require_relative 'arche/data_frame'

##
# Home of Arche::DataFrame, and its related classes and mixins.
module Arche
  ##
  # Error thrown when trying to mutate data that may cause data inconsistentcy,
  # i.e. yet unaccounted methods.
  class MutationError < IndexError; end

  @sql_converters = {
    NilClass => -> { 'NULL' },
    TrueClass => -> { 1 },
    FalseClass => -> { 0 }
  }

  class << self
    ##
    # Returns a new range from a range which is neither endless nor beginless.
    # This ensures that the range now may be called with minmax and to_a
    def bound_range(range, max)
      from = begin
        range.first
      rescue RangeError
        nil
      end

      to = begin
        range.last
      rescue RangeError
        nil
      end

      from ||= to.negative? ? -[max, to.abs].max : 0
      to   ||= from.negative? ? -1 : [max, from].max

      from..to
    end

    ##
    # Converts a *indices, a set of integers an ranges to a sorted Set, i.e.
    # with no duplicate values. Ranges may be bound with the bound: argument to
    # avoide nedless and beginless ranges, allowing calling to_a on them.
    def index_set_of(*indices, bound:)
      ranges, ints = indices.partition { |item| item.respond_to?(:minmax) }
      ranges.map! { |range| Arche.bound_range(range, bound) }
      ranges.map!(&:to_a).flatten!
      Set.new(ranges + ints).sort
    end

    ##
    # Map of classes and converstion to SQL statement,
    attr_reader :sql_converters

    ##
    # Converting value to SQL statemnt with sql_converts, default to .to_s
    def primitive_to_sql(val)
      conv = @sql_converters[val.class]
      if conv
        conv.call(val)
      else
        val.to_s
      end
    end
  end
end
