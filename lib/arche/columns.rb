# frozen_string_literal: true

module Arche
  ##
  # The data container for DataFrame. Columns is Hash thus mapping names to data
  # - just as a column. Includes ActionCallback to enrute that the parent
  # DataFrame's row maintian its acessors after keys has changed.
  class Columns
    extend Forwardable
    include Mixins::Range
    extend Mixins::ActionCallback

    ##
    # Initializes with a DataFrame instance, and sets columns with **kwargs
    def initialize(data_frame, **kwargs)
      @data_frame = data_frame
      @data = {}
      set(**kwargs) if kwargs.any?
    end

    ##
    # Delegates to @data, hash, when method i smissing.
    def method_missing(meth, *args, **kwargs, &block)
      return @data.send(meth, *args, **kwargs, &block) if @data.respond_to?(meth)

      super(meth, *args, **kwargs, &block)
    end

    def respond_to_missing?(meth)
      @data.respond_to?(meth)
    end

    def_delegators :@data,
                   *%i(keys size values key? fetch fetch_values first last map
                       each each_key each_pair any? all? clear delete_if reject!
                       select! filter! shift)

    %i(
      replace transform_keys! transform_values!
    ).each do |meth|
      define_method(meth) do
        raise MutationError, ":#{meth} on @data is prohibited as it may mutate data causing DataFrame inconsistency."
      end
    end

    alias names keys
    alias ncol size
    alias columns values

    ##
    # Access a column by either its name. Accessing undefined columns will
    # raise an KeyError.
    #
    #   columns[:a]
    #   => [0, 2, 3, ...]
    def [](*keys)
      values_at(*keys)
    end

    ##
    # Add/replace column from array. Best pracitce is to provde symbol names.
    # Second best is string names. Converts arrayinto a Column.
    #
    #   columns[:a] = [1, 2, 3]
    #   => [1, 2, 3]
    #   columns[:b] = nil
    #   => [nil, nil, nil]
    #   columns[:c] = [1]
    #   => ArgumentError "Incompatible dimension!"
    def []=(key, array)
      unless key.is_a?(Symbol) || key.is_a?(String)
        raise ArgumentError, 'A column name must either be a Symbol or string'
      end

      array = [array] * [nrow, 1].max unless array.respond_to? :each

      replacing = ((size == 1) && (key == keys[0]))
      if (array.size != nrow) && !(replacing || size.zero?)
        raise ArgumentError, "Trying to add column with length #{array.size} different form nrow"
      end

      @data[key] = Column.new(self, array.to_a)
    end

    ##
    # Setting multiple columns with []=
    def set(**kwargs)
      kwargs.each do |k, v|
        self[k] = v
      end
    end

    ##
    # Returning Column instances for given keys. When just one key is given a
    # single instance is returnes otherwise an array og Column instances are
    # returnes
    def values_at(*keys)
      if keys.size == 1
        fetch(keys[0])
      else
        fetch_values(*keys)
      end
    end

    ##
    # Ranme columns from a hash of old and new names
    def rename(**args)
      unless args.values.all? { |name| name.is_a?(String) || name.is_a?(Symbol) }
        raise ArgumentError, 'args must comprise of strings and symbols only'
      end

      args.each do |old_name, new_name|
        @data[new_name] = @data.delete(old_name) if key?(old_name)
      end
    end

    ##
    # delete all columns in keys
    def delete(*keys)
      keys.map do |k|
        @data.delete(k) if key?(k)
      end
    end

    ##
    #
    def delete_if(&block)
      @data.delete_if(&block)
    end

    ##
    # Mutates each colum to hold values at given indices
    def select_rows_at!(*indexes)
      first[1].select_rows_at!(*indexes) if ncol.positive?
      self
    end

    ##
    # Returns a subset of given columns
    def slice(*keys)
      raise KeyError, "Undefined keys (#{keys - self.keys})" if (keys - self.keys).any?

      new @data.slice(*keys)
    end

    ##
    # As :slice, but reduces or rearagnes to keys.
    def slice!(*keys)
      raise KeyError, "Undefined keys (#{keys - self.keys})" if (keys - self.keys).any?

      @data = @data.slice(*keys)
      self
    end
    alias rearange! slice!

    ##
    # Returns a new Columns instance merged with another column hash. If other
    # comprises non string nro symbol keys and its values does not shape to nrow
    # ArgumentError will be raised.
    def merge(other)
      if compatible_hash?(other)
        new @data.merge(other.to_h)
      else
        raise ArgumentError, "Incompativle hash or columns object. Alle keys should be symbols/strings and all values have size of #{nrow}"
      end
    end

    ##
    # Works like set, but checks for compatibilty before merging in, avoiding
    # setting some columns and not all.
    def merge!(other)
      @data = merge(other)
      self
    end

    ##
    # Delegates sort to @data, and converts back to hash.
    def sort(&block)
      @data.sort(&block).to_h
    end

    ##
    # Sorts columns and mutates to new order.
    def sort!(&block)
      @data = sort(&block)
    end

    after_action :merge!, :slice!, :delete, :[]=, :clear, :delete_if, :select!, :reject!, :filter!, :shift, :rename do
      @data_frame.row.maintain_accessors if @data_frame
    end

    def ==(other)
      return false unless other.respond_to? :each
      return false if size != other.size
      return false unless other.respond_to? :keys
      return false if keys != other.keys
      return false unless other.respond_to? :values

      values.zip(other.values).all? do |a, b|
        a == b
      end
    end

    ##
    # Number of items in a column, i.e. rows
    def nrow
      values.first&.size || 0
    end

    ##
    # nrow x ncol
    def dim
      [nrow, ncol]
    end

    def inspect
      "#<Arche::Columns #{@data.inspect}>"
    end

    ##
    # Returns duplicated data as hash.
    def to_h
      to_a.to_h
    end

    ##
    # Converts @data to array; duplicates to break pointers
    def to_a
      @data.map { |k, v| [k, v.to_a] }
    end

    private

    def new(hash)
      Arche::DataFrame.new(**hash).columns
    end

    def compatible_hash?(other)
      other.all? do |key, val|
        (key.is_a?(Symbol) || key.is_a?(String)) && (val.size == nrow)
      end
    end
  end
end
