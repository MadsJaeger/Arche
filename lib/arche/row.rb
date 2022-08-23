# frozen_string_literal: true

module Arche
  ##
  # A slice of the Arche::Columns at a given position. Internal to DataFrame
  # who persist its accessor when adding and removing columns. It conveys
  # convenient accessors:
  #
  #   row['sex'] => :male
  #   row.sex = :female
  #   => :female
  class Row
    extend Forwardable
    include Mixins::Range
    extend Mixins::Statistics
    delegate_statistic_to :values
    def_delegators :@data_frame, *%i(nrow ncol column_names)
    def_delegators :to_h, *%i(slice to_json to_yaml)
    def_delegators :values, *%i(values_at map each group_by)

    def initialize(data_frame)
      @accessors = []
      @position = 0
      @data_frame = data_frame
    end

    def inspect # :nodoc:
      "<Arche::Row #{to_h.inspect}>"
    end

    ##
    # Acessing by key, row[:sex] => :male
    def [](col)
      @data_frame.columns[col][@position]
    end

    ##
    # Setting by key, row[:sex] = :female
    def []=(col, value)
      @data_frame.columns[col][@position] = value
    end

    ##
    # All values sorted in order of columns
    def values
      @data_frame.map_columns { |_name, col| col[@position] }
    end
    alias to_a values

    ##
    # For setting all values to a constant or an array with size ncol
    def values=(data)
      data = [data] unless data.respond_to? :each

      case data.size
      when 1
        @data_frame.each_column { |_name, col| col[@position] = data[0] }
      when ncol
        @data_frame.columns.each_with_index { |set, index| set[1][@position] = data[index] }
      else
        raise ArgumentError, "expected argument to have size of 1 or #{ncol}"
      end
    end

    def to_h
      @data_frame.column_names.zip(values).to_h
    end

    ##
    # For changing the osition and acces other data of the data frame.
    def position=(index)
      raise_index_error(index) unless in_range?(index)
      @position = index
    end

    ##
    # Current position in DataFrame
    attr_reader :position

    ##
    # Persists conveinent acessors from the column names of parent DataFrame.
    def maintain_accessors
      (@data_frame.column_names - @accessors).each do |k|
        define_column_accessor(k)
      end
      (@accessors - @data_frame.column_names).each do |k|
        remove_column_accessor(k)
      end
      @accessors = @data_frame.column_names
    end

    ##
    # Block change of values
    def map!
      return enum_for(:map!) unless block_given?

      @data_frame.columns.values.map { |col| col[@position] = yield col[@position] }
    end

    def ==(other)
      (to_h == other) || (values == other) || (other.is_a?(Row) && to_h == other.to_h)
    end

    def eql?(other)
      other.is_a?(Row) && other.instance_variable_get("@data_frame").equal?(@data_frame) && @position == other.position
    end

    private

    def size
      @data_frame.nrow
    end

    def define_column_accessor(name)
      @accessors << name
      singleton_class.class_eval do
        define_method(name) do
          self[name]
        end
        define_method("#{name}=") do |value|
          self[name] = value
        end
      end
    end

    def remove_column_accessor(name)
      @accessors.delete name
      singleton_class.class_eval do
        remove_method name
        remove_method "#{name}="
      end
    end
  end
end
