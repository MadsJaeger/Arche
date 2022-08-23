# frozen_string_literal: true

module Arche
  ##
  # DataFrame class comparable to Pythons pandas DataFrame or R's core data.frame.
  # A DataFrame is usefull for data operations and analytics. It can be leveraged
  # in procedural programming manipulating SQL databases, CSV files, etc. The core
  # of the class is its @columns instance, a composition to a Hash storing column
  # names with associated records as Arche::Column instances, see Arche::Columns.
  # A DataFrame is itterated through its rows, however, only one row exists whose
  # pointer change through iteration. This row respond to each column name. Column
  # names may only be symbols, and each column must hav the same length. However,
  # due to the openess of Ruby you may violate the data integrity of a DataFrame,
  # which can cause later errors.
  class DataFrame
    extend Forwardable
    include Enumerable
    include Mixins::Range
    def_delegators :@columns, *%i(nrow ncol dim keys to_h key?)
    alias size nrow

    ##
    # A DataFrame instance holds a @columns instance to store the data in a key
    # column hash, and a @row to itterate through data of the @columns. When
    # instantiating the argument in data, if given, will be convereted to a hash
    # representing the columns data, which then will be set to @columns. The first
    # class method in convert_* which responds true on *?(data) is used for
    # converitng data to a hash. If none of the class methods are applicable for
    # the data .to_h is called. Argument col_names: should be an array of symbols
    # and given when data is an array of arrays. **columns are set directly to
    # @columns.
    #
    #   DataFrame.new a: [1, 2], b: [3, 4]
    #   DataFrame.new [[1,3],[2,4]], col_names: %i(a b)
    #   DataFrame.new [{a: 1, b: 3}, {a: 2, b: 4}]
    #   # all produces
    #   # Arche::DataFrame (2,2)
    #   #   a   b
    #   # --- ---
    #   #   1   3
    #   #   2   4
    def initialize(data = nil, col_names: nil, **columns, &_block) # :doc:
      @row     = Row.new(self)
      @columns = Columns.new(self)

      # If data given find a convert_** that can convert data to hash and then
      # set columns. If data given and no converter found try to convert the data
      # by to_h and then set the columns.
      if data
        found = self.class.converters.find do |cc|
          check_with = "#{cc[8..]}?"
          next unless self.class.send(check_with, data)

          hash = self.class.send(cc, data, col_names: col_names)
          @columns.set(**hash)
          true
        end
        @columns.set(**data.to_h) unless found
      end

      yield self if block_given?
      @columns.set(**columns) if columns.any?
    end

    class << self
      ##
      # List of class methods looking beginning with convert_, used when initializing
      # with convertion of data into a hash. All conert_* methods should have a
      # compatnion *? stating heter or not the method expects to be able to convert
      # its argument to a hash.
      def converters
        methods.select { |meth| meth.start_with?('convert_') }
      end

      ##
      # Is argument and array of hashes, and may then be converted to hash with
      # convert_array_of_hashes
      def array_of_hashes?(arg)
        arg.is_a?(Array) && arg.first.is_a?(Hash)
      end

      ##
      # Converts and array of hashes to a single column hash.
      def convert_array_of_hashes(array_of_hashes, col_names: nil)
        col_names = array_of_hashes.map(&:keys).flatten.uniq
        data = array_of_hashes.map do |hash|
          hash.values_at(*col_names)
        end
        col_names.zip(data.transpose).to_h
      end

      ##
      # Is argument and array of arrays, and may then be converted to hash with
      # convert_array_of_arrays
      def array_of_arrays?(arg)
        arg.is_a?(Array) && arg.first.is_a?(Array)
      end

      ##
      # Converts an array of arrays along a list of symbols in col_names, to a
      # hash of columns
      def convert_array_of_arrays(array_of_arrays, col_names:)
        raise ArgumentError, '`col_names:` should be an array' unless col_names.is_a? Array

        transposed = if array_of_arrays.empty?
                       col_names.map { |_name| [] }
                     else
                       array_of_arrays.transpose
                     end

        if transposed.size != col_names.size
          raise ArgumentError, "Trying to add #{transposed.size} columns but got #{col_names.size} column names"
        end

        col_names.zip(transposed).to_h
      end
    end

    ##
    # Itterates the rows, yielding the same @row instnace for each row with
    # a changed position.
    def each
      return enum_for(:each) unless block_given?

      (0..(nrow - 1)).each do |pos|
        @row.instance_eval { @position = pos }
        yield @row
      end
    end
    alias rows each
    alias each_row each
    alias map_rows map

    ##
    # The @row instance, change its poistion for representing another row.
    # Yields @row if block_given?
    def row
      yield @row if block_given?
      @row
    end

    ##
    # The @row instance at a given position, integer in range. Out of range
    # position will raise an error.
    def row_at(index)
      @row.position = index
      yield @row if block_given?
      @row
    end

    ##
    # First row
    def first
      return nil if nrow.zero?
      row_at(0)
    end

    ##
    # Last row
    def last
      return nil if nrow.zero?
      row_at(-1)
    end

    ##
    # Contianer of data mapping column names to columns (arrays)
    attr_reader :columns

    ##
    # Inserts new columns or updates existing. Takes a hash as argment where the
    # keys must be symbols, and the values an iterable with the length of nrow.
    def columns=(hash)
      @columns.set(**hash)
    end

    ##
    # \Returns a column by name, raises KeyError if the name is not a stored
    # column name.
    def column(name)
      yield @columns[name] if block_given?
      @columns[name]
    end

    ##
    # The keys/names of the columns
    def column_names
      @columns.names
    end

    ##
    # Itterating columns yielding |name, column|
    def each_column(&block)
      @columns.each(&block)
    end

    ##
    # Mapping columns yielding |name, column|
    def map_columns(&block)
      @columns.map(&block)
    end

    ##
    # Transforming columns yiyelding |column|. Note that you may change each
    # column lenght and order individually violating data integrity.
    def transform_columns(&block)
      @columns.transform_values(&block)
    end

    ##
    # all? on @columns, yielding |name, column|
    def all_columns?(&block)
      @columns.all?(&block)
    end

    ##
    # any? on @columns, yielding |name, column|
    def any_column?(&block)
      @columns.any(&block)
    end

    ##
    # find on @columns, yielding |name, column|
    def find_column(&block)
      @columns.find(&block)
    end

    ##
    # slice on @columns, selecting multiple or a single column, returning a subset
    # of the @columns hash.
    def slice(*keys)
      @columns.slice(*keys)
    end

    ##
    # \Returns columns without its keys for one or more names.
    def columns_at(*keys)
      if keys.size == 1
        [@columns[keys.first]]
      else
        @columns.values_at(*keys)
      end
    end

    ##
    # For accessing a position, row, rows, column, columns or slice. When
    # accessing out of range an error will be raised. The *args should be
    # integers or  ranges of integers for acessing rows, and symbols for accessing
    # columns. The order of the arguments does not matter.
    #
    #   [integer,column_name] => postional access, returns value at integer for column_name
    #   [integer]{|row| ...} => returns a row instnace at integer, block is optional
    #   [*integers] => returns a DataFrame, for the subset of rows
    #   [*ranges_of_integers] => as above
    #   [column_name]{|column| ...} => returns a column at column_name, block is optional
    #   [*column_names] => returns a new DataFrame instance for the subset of columns
    #   [integer,*columns_names] => returns a new DataFrame with one row
    #   [*integers,*column_names] => returns a new DataFrame for the subset of rows and integers
    #
    def [](*args, &block)
      cols, rows = partition_args(*args)
      check_columns! cols

      case dimensional_access(rows, cols)
      when :row
        row_at(rows[0], &block)
      when :col
        column(cols[0], &block)
      when :point
        @columns[cols[0]][*rows]
      when :columns
        self.class.new(**@columns.instance_eval do
          @data.slice(*cols)
        end)
      when :rows
        values_at(*rows)
      when :hyper_set
        selected_cols = @columns.values_at(*cols)
        selected_rows = selected_cols.map { |col| col.values_at(*rows) }
        data          = cols.zip(selected_rows).to_h
        self.class.new(**data)
      end
    end

    ##
    # For setting values in the DataFrame. Like :[] it takes an unorderd list
    # of positional arguments, but requires at least two arguments, and the last
    # is the value to set. The value argument must be dimensioned equally to
    # the sliced data frame or be a constant. If the value argument is a constant
    # it is duplicated and set to the sliced data frame.
    #
    # FIXME: df[0..1,:a,:b] = [1,2,3,4] -> raises ArgumentError, but should be
    # possible. Decide wheter it is set by rows or columns.
    # df[0..1,:a,:b] = [1,2], sets 1,2 on each row, but, df[0..1,:a,:b] = [[1,2],[3,4]]
    # does not set the new values on each row but sets each row with [1,2],[3,4].
    #
    #   [:undefined_column] = nil => adds a new column
    #   [out_of_range_row] = nil -> raises index error
    #   [row] = nil => sets all values to nil on row
    #   [row] = [...] => changes all row values
    #   [row, :columns] = [...] => changes row values at columns
    #   [:column] = [...] replaces column
    #   [row,columns] = nil => nilifies subset
    #
    def []=(*args)
      raise ArgumentError 'At least to arguments must be given' if args.size < 2

      cols, rows = partition_args(*args[0..-2])
      value = args[-1]

      case dimensional_access(rows, cols)
      when :row
        row_at(rows[0]).values = value
      when :point # or multiple rows
        @columns[cols[0]][rows] = value
      when :col, :columns
        arr_val = value.respond_to?(:each) ? value : [value] * nrow
        cols.each do |name|
          if @columns.key? name
            @columns[name].replace! arr_val
          else
            @columns[name] = arr_val
          end
        end
      when :rows
        set = Arche.index_set_of(*rows, bound: nrow - 1)
        raise_index_error('rows') unless in_range?(set)

        set.each do |pos|
          @row.instance_eval { @position = pos }
          @row.values = value
        end
      when :hyper_set
        @columns.values_at(*cols).each do |col|
          col[rows] = value
        end
      end
    end

    ##
    # \Returns an array of indexes where block returns truthy on row, i.e. all
    # positions where a criteria holds.
    def select_indexes(&block)
      return enum_for(:select_indexes) unless block_given?

      each_with_index.select { |row, _index| block.call(row) }.map(&:last)
    end

    ##
    # \Returns a new DataFrame instance where block returns truthy by row.
    def select(&block)
      return enum_for(:select) unless block_given?

      indices = select_indexes(&block)
      self[*indices]
    end

    ##
    # Selects all rows where block returns truthy; mutates self.
    def select!(&block)
      return enum_for(:select!) unless block_given?

      indices = select_indexes(&block)
      @columns.first[1]&.send('subset_rows_at!', *indices) # private method skipping in_range?
      self
    end

    ##
    # Indexes to reject where block returns truthy
    def reject_indexes(&block)
      return enum_for(:select_indexes) unless block_given?

      each_with_index.reject { |row, _index| block.call(row) }.map(&:last)
    end

    ##
    # \Returns a new DataFrame instance where rows has been rejected by block.
    def reject(&block)
      return enum_for(:reject) unless block_given?

      indices = reject_indexes(&block)
      self[*indices]
    end

    ##
    # Mutating verison of :reject, reverse of :select!
    def reject!(&block)
      return enum_for(:reject!) unless block_given?

      indices = reject_indexes(&block)
      @columns.first[1]&.send('subset_rows_at!', *indices) # private method skipping in_range?
      self
    end

    ##
    # *args may be a mix of integers and symbols identifying rows and columns
    # to detele.
    def delete_at!(*args)
      cols, rows = partition_args(*args)
      @columns.delete(*cols)
      @columns.first[1]&.delete_rows_at!(*rows)
      self
    end

    ##
    # \Returns a new data frame isntnace for roes in *indexes.
    def values_at(*indexes)
      self.class.new(**map_columns do |name, col|
        [name, col.values_at(*indexes)]
      end.to_h)
    end

    ##
    # Returns a clone sorted by columns with **kwargs, see Column#rearange
    def sort(*cols, **kwargs)
      clone.sort!(*cols, **kwargs)
    end

    ##
    # Sorts each columns with **kwargs, see Column#rearange. Calling sort!
    # mutates the order of the rows.
    def sort!(*cols, **kwargs)
      check_columns! cols
      cols.each do |name|
        @columns[name].sort!(**kwargs)
      end
      self
    end

    ##
    # Like :sort_by! but returns a sorted clone.
    def sort_by(&block)
      return enum_for(:sort_by) unless block_given?

      dup.sort_by!(&block)
    end

    ##
    # Rearagnes rows given block, mutates the order.
    def sort_by!(&block)
      return enum_for(:sort_by!) unless block_given?

      indices = map(&:clone).sort_by(&block).map(&:position)
      @columns.first[1]&.send('subset_rows_at!', *indices)
      self
    end

    ##
    # \Returns a new reverted data frame
    def reverse
      dup.reverse!
    end

    ##
    # Reverts the order
    def reverse!
      @columns.first[1]&.reverse!
      self
    end

    ##
    # :method: +
    # Adds another equally dimensioned dataframe onto own data, returns a new data frame

    # :method: add!
    # Mutating version of +

    # :method: -
    # Subtracts another equally dimensioned dataframe from own data, returns a new data frame

    # :method: subtract!
    # Mutating version of -

    # :method: *
    # Multiplies another equally dimensioned dataframe onto own data, returns a new data frame

    # :method: mult!
    # Mutating version of *

    # :method: /
    # Divides with another equally dimensioned dataframe, returns a new data frame

    # :method: divide!
    # Mutating version of /

    # :method: **
    # Computes the power with another equally dimensioned dataframe, returns a new data frame

    # :method: power!
    # Mutating version of **

    # :method: %
    # Takes the modulo to another equally dimensioned dataframe, returns a new data frame

    # :method: modulo!
    # Mutating version of %
    {
      :+ => 'add!',
      :- => 'subtract!',
      :* => 'mult!',
      :/ => 'divide!',
      :** => 'power!',
      :% => 'modulo!'
    }.each do |operand, banged|
      define_method(operand) do |df| # :doc:
        self.class.new(**zip_map(df, &operand))
      end

      define_method(banged) do |df|
        hash = zip_map(df, &operand)
        @columns = Columns.new(self)
        @columns.set(**hash)
        self
      end
    end

    ##
    # Zips another data frame onto self ad calls block on each ziped column,
    # returning a new columns hash.
    #
    #   data = {a: 0..4}
    #   df = DataFrame.new(**data)
    #   odf = DataFrame.new(**data)
    #   df.zip_map(odf, &:+)
    #   => {:a=>[0, 2, 4, 6, 8]}
    #
    def zip_map(df, &block)
      block = ->(a, b) { a.send(block, b) } if block.is_a?(Symbol)

      if df.respond_to?(:each)
        raise ArgumentError, 'incompatible dimensions' if dim != df.dim

        column_names.zip(df.column_names).map do |a, b|
          [a, block.call(@columns[a], df.columns[b])]
        end.to_h
      else
        @columns.transform_values do |col|
          block.call(col, df)
        end
      end
    end

    ##
    # Transposes from column data to row data, i.e. returns an array of arrays
    # whre each element represent row values.
    def transpose
      @columns.values.map(&:to_a).transpose
    end
    alias to_a transpose

    ##
    # Converts data to string like inspect
    def to_s(**kwargs)
      inspect_columns(**kwargs.merge(items: nrow))
    end

    ##
    # Converts data to array of hashehs
    def to_hashes
      transpose.map { |row| column_names.zip(row).to_h }
    end

    ##
    # Converts :to_hashes to json, i.e. json rows.
    def to_json(*args)
      ::JSON.generate(to_hashes, *args)
    end

    ##
    # Converts to yaml rows
    def to_yaml
      to_hashes.to_yaml
    end

    ##
    # Produces an SQL insert statement. type: may be :ignore, :update or blank
    # for inser ignore, insert update and regular insert statment. primary_keys:
    # is used for insert_update.
    def to_sql_insert(table_name, type: nil, primary_keys: [])
      values = map do |row|
        inner = row.values.map do |val|
          Arche.primitive_to_sql(val)
        end.join(', ')
        "(#{inner})"
      end.join("\n")
      names  = column_names.map { |name| "`#{name}`" }.join(', ')
      inner  = "`#{table_name}`\n(#{names})\nVALUES\n#{values};"
      case type
      when :ignore
        "INSERT IGNORE INTO #{inner}"
      when :update
        if primary_keys.empty?
          raise ArgumentError, 'Missing argument :primary_keys for insert update query (keys to math on).'
        end

        update_values = (column_names - primary_keys).map { |key| "`#{key}` = VALUES(`#{key}`)" }.join(', ')
        "INSERT INTO #{inner[..-2]}\nON DUPLICATE KEY UPDATE\n#{update_values};"
      else
        "INSERT INTO #{inner}"
      end
    end

    ##
    # Mutatable appention of other to self. Other may be anything that can be
    # coreced into a DataFrame. If given array own column_names are used, thus
    # array must be an array of rows each riw length of ncol.
    def <<(other)
      df = self.class.new other, col_names: column_names
      nrow_was = nrow
      @columns.each do |name, col|
        if df.key? name
          col.concat df[name].to_a
        else
          col.concat [nil] * df.nrow
        end
      end
      (df.column_names - column_names).each do |name|
        @columns[name] = ([nil] * nrow_was) + df[name].to_a
      end
      self
    end

    ##
    # Retuens hash of grouped DataFrames, either by goruping on columns are by
    # block.
    def group_by(*keys, &block)
      return enum_for(:group_by) unless block_given? || keys.any?

      group_indexes(*keys, &block).transform_values do |rows|
        values_at(*rows)
      end
    end

    ##
    # Returns a hash like {group_key => array_of_positions}. If keys to group
    # on (column_names) are supplied blovk will not be called, and grouping by
    # colums is applied.
    def group_indexes(*keys, &block)
      return enum_for(:group_indexes) unless block_given? || keys.any?

      if keys.any?
        columns_at(*keys).reduce(&:zip).zip(0..nrow).group_by(&:first)
      else
        each_with_index.group_by { |row, _index| yield row }
      end.transform_values { |arr| arr.map(&:last) }
    end

    ##
    # Merging other DataFrame onto self. Returns a new DataFrame, whereas
    # merge! mutates. Argument :how may be :left, :inner, :outer. If :right is
    # needed the consumer should coll :left on the right instead. Argumen :by
    # may be a single column or a range of columns. All columns in by must be
    # represented in both DataFrames. If columns on the right DataFrame ar given
    # in the left DataFrame the former will be returned in the new DataFrame, as
    # the columns in the left will be overridden by the matching in the right.
    # The original order of the left dataframe is persisted and, eny elements in
    # the right when joining as :outer will be appended to the buttom of the
    # new DataFrame.
    def merge(df, by:, how: :outer)
      by        = [*by]
      cn_self   = column_names - by
      cn_df     = df.column_names - by
      data_self = columns_at(*cn_self).map(&:to_a).transpose
      data_df   = df.columns_at(*cn_df).map(&:to_a).transpose
      gr_self   = group_indexes(*by)
      gr_df     = df.group_indexes(*by)

      case how
      when :left
        gr_df = gr_df.slice(*gr_self.keys)
      when :inner
        union   = gr_self.keys & gr_df.keys
        gr_self = gr_self.slice(*union)
        gr_df   = gr_df.slice(*union)
      end

      merged = gr_self.each_with_object({}) do |(key, pos), merge|
        merge[key] = [pos, gr_df[key] || []]
      end

      if how == :outer
        (gr_df.keys - gr_self.keys).each do |key|
          merged[key] = [[], gr_df[key]]
        end
      end

      nil_self = [nil] * cn_self.size
      nil_df   = [nil] * cn_df.size

      joined = merged.map do |key, pos|
        a = data_self.values_at(*pos[0])
        b = data_df.values_at(*pos[1])

        if a.empty?
          b.map { |row| [*key] + nil_self + row }
        elsif b.empty?
          a.map { |row| [*key] + row + nil_df }
        else
          a.map { |row_a| b.map { |row_b| [*key] + row_a + row_b } }.flatten(1)
        end
      end.flatten(1)

      self.class.new joined, col_names: by + cn_self + cn_df
    end

    ##
    # Does the other have same keys and does each value in other equal corresponding
    # column in self. Intended to work on toher data frame or hash. The ordering of
    # columns do not matter.
    def ==(other)
      return false unless other.respond_to? :keys
      return false unless (keys & other.keys).size == ncol

      all_columns? do |name, col|
        col == other[name]
      end
    end

    ##
    # \Returns a string, parses argument to inspect_column
    def inspect(**args)
      str = "Arche::DataFrame (#{nrow},#{ncol})\n"
      str += inspect_columns(**args)
      str
    end

    ##
    # Duplicate column values an instantiate new
    def dup
      self.class.new(**transform_columns(&:dup))
    end

    ##
    # Clones column values an instantiate new
    def clone
      self.class.new(**transform_columns(&:clone))
    end

    ##
    # Converts column to readable tring. items: represents no. of top and
    # buttom rows to print. min_width: represents the minmal character width of
    # the column when printed and correspondingly does max_width: represent when
    # data is to be truncated
    def inspect_column(key, items: 6, min_width: 3, max_width: 25)
      block = ->(v) { v.nil? ? 'nil' : v.to_s }
      col = columns[key]
      strings = [key.to_s]
      strings << 'DIV'
      if nrow > (items * 2)
        strings += col[0..items].map(&block)
        strings << '***'
        strings += col[-items..].map(&block)
      else
        strings += col.map(&block)
      end
      width = [[strings.map(&:size).max, min_width].max, max_width].min
      strings[1] = '-' * width
      str_size = width - 3
      strings.map! do |str|
        mstr = if str.size > width
                 str[0..str_size] + '...'
               else
                 str
               end
        "%#{width}.#{width}s" % mstr
      end
      strings
    end

    ##
    # :inspect_column on all columns parsing **args
    def inspect_columns(**args)
      column_names.map do |name|
        inspect_column(name, **args)
      end.transpose.map do |row|
        row.join(' ')
      end.join("\n")
    end

    private

    def partition_args(*args)
      args.partition { |arg| arg.is_a?(Symbol) || arg.is_a?(String) }
    end

    def check_columns!(cols)
      raise KeyError, "Undefined column(s) '#{cols - column_names}'" if (cols - column_names).any?
    end

    def dimensional_access(rows, cols)
      # [0] => one row
      if (rows.size == 1) && rows[0].is_a?(Integer) && cols.size.zero?
        :row
      # [:col] => one column
      elsif (cols.size == 1) && rows.size.zero?
        :col
      # [0, :col] => point / [range, integers, :col] => subset on column
      elsif cols.size == 1
        :point
      # [:col2, :col1] => subset columns
      elsif (cols.size > 1) && rows.size.zero?
        :columns
      # [0..3, -1] => subset rows
      elsif cols.size.zero? && !rows.size.zero?
        :rows
      # [0..3, :col1, :col2] => subset rows and columns
      else
        :hyper_set
      end
    end
  end
end
