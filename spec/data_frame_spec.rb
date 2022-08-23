# frozen_string_literal: true
require 'date'

RSpec.describe Arche::DataFrame do
  let :empty do
    Arche::DataFrame.new
  end

  let :data do
    {
      a: (0..19).to_a,
      b: (0..19).to_a.reverse
    }
  end

  let :df do
    Arche::DataFrame.new(**data)
  end

  let :extra_col do
    ('a'..'t').to_a
  end

  describe '#initialize' do
    @data = {
      a: (0..19).to_a,
      b: (0..19).to_a.reverse
    }

    @arrays = @data.map do |_key, col|
      col
    end.transpose

    @hashes = @arrays.map do |arr|
      @data.keys.zip(arr).to_h
    end

    [
      ['#columns= with columns', nil, nil, @data],
      ['#set_from_arrays with array of arrays', @arrays, @data.keys, {}],
      ['#set_from_hashes with array of hashes', @hashes, nil, {}]
    ].each do |text, arr, names, cols|
      it text do
        df = Arche::DataFrame.new(arr, col_names: names, **cols)
        data.each_key do |key|
          expect(df.column(key)).to eq(data[key])
        end
      end
    end

    it 'can initialize from a row' do
      df1 = Arche::DataFrame.new a: 1, b: 2
      row = Arche::Row.new df1
      df2 = Arche::DataFrame.new row
      expect(df2).to eq(df1)
      expect(df2).to_not equal(df1)
      expect(df2[:a]).to_not equal(df1[:a])
      expect(df2.to_a).to eq([[1, 2]])
    end

    it 'can initialize from a DataFrame' do
      df0 = Arche::DataFrame.new df
      expect(df0).to eq(df)
      expect(df0).to eq(data)
      expect(df0).to_not equal(df)
      df0.columns.each do |name, col|
        expect(col).to eq(df[name])
        expect(col).to_not equal(df[name])
      end
    end

    it 'can initialize from a single hash' do
      df = Arche::DataFrame.new({a: [1, 2], b: [3, 4]})
      expect(df.to_a).to eq([[1, 3], [2, 4]])
    end

    it 'raises ArgumentError if array of arrays are given but no column names' do
      expect { Arche::DataFrame.new [[1, 2]] }.to raise_error(ArgumentError)
    end

    it 'raises argument error when array is given but rows are not of arrays or hashes' do
      expect { Arche::DataFrame.new [Object.new] }.to raise_error(TypeError)
    end

    it 'raises argument error if data given and can not be parsed' do
      expect { Arche::DataFrame.new Object.new }.to raise_error(NoMethodError)
    end

    it '@columns exists' do
      expect(df.instance_variable_get('@columns')).to equal(df.columns)
    end

    it '@row exists' do
      expect(df.instance_variable_get('@row')).to equal(df.row)
    end

    it '@row responds to all column_names' do
      all = df.column_names.all? do |name|
        df.row.respond_to? name
        df.row.respond_to? "#{name}="
      end
      expect(all).to be(true)
    end
  end

  describe 'accessing rows' do
    it '#row return an unspecified row instance' do
      row = df.row do |r|
        r.position = 2
        r.a = 5
      end
      expect(row).to equal(df.instance_variable_get('@row'))
      expect(row.a).to be(5)
      expect(row.position).to be(2)
    end

    it '#row_at returns row at position' do
      row = df.row_at(2) do |r|
        r.a = 5
      end
      expect(row).to equal(df.instance_variable_get('@row'))
      expect(row.a).to be(5)
      expect(row.position).to be(2)
    end

    it '#rows return enumerator' do
      expect(empty.rows.is_a?(Enumerator)).to be(true)
    end

    it '#rows itterates empty data' do
      expect(empty.map(&:clone)).to eq([])
    end

    it '#rows allows itterating rows' do
      df.each_row do |row|
        row.a = 1
      end
      expect(df.columns[:a]).to eq([1] * df.nrow)
    end

    it '#map returns new data' do
      expect(df.map_rows(&:a)).to eq(data[:a])
    end
  end

  describe 'accessing columns' do
    it '#columns= appends/sets columns' do
      df.columns = { a: data[:b], c: data[:b], 'd' => data[:b] }
      expect(df.column_names).to eq(%i(a b c) + ['d'])
      df.each_column do |_name, col|
        expect(col).to eq(data[:b])
      end
    end

    it '#column returns column' do
      df.column(:a) do |col|
        col.map! { |v| v + 1 }
      end
      expect(df.column(:a)).to eq(data[:a].map { |v| v + 1 })
    end

    it '#column_names' do
      expect(df.column_names).to eq(%i(a b))
    end

    it '#each_column' do
      data = {}
      df.each_column do |name, col|
        data[name] = col
      end
      expect(df).to eq(data)
    end

    it '#map_columns' do
    end
  end

  describe '#[] two-dimensional access' do
    it '#[] returns emoty DataFrame' do
      res = df[]
      expect(res.dim).to eq([0,0])
      expect(df).to_not equal(res)
    end

    it '#[:column_name] returns column' do
      expect(df[:a]).to eq(df.column(:a))
    end

    it '#[range, :column_name] returns subset on column' do
      expect(df[0..3, :a]).to eq(data[:a][0..3])
    end

    it '#[integer] returns row' do
      expect(df[0]).to eq(df.row_at(0))
    end

    it '#[integer, :column_name] returns a value' do
      expect(df[0, :a]).to be(0)
      expect(df[0, :b]).to be(19)
      expect(df[-1, :a]).to be(19)
    end

    it '#[range] returns subset on rows' do
      res = df[0..4]
      expect(res).to be_instance_of(Arche::DataFrame)
      expect(res.dim).to eq([5, 2])
      expect(res).to eq(data.transform_values { |v| v[0..4] })
    end

    it '#[range] returns subset on rows' do
      res = df[0..4]
      expect(res).to be_instance_of(Arche::DataFrame)
      expect(res.dim).to eq([5, 2])
      expect(res).to eq(data.transform_values { |v| v[0..4] })
    end

    it '#[range, integers] returns hyperset rows' do
      res = df[0, 0..5, -1, -5, 0]
      exp = {
        a: [0, 0, 1, 2, 3, 4, 5, 19, 15, 0],
        b: [19, 19, 18, 17, 16, 15, 14, 0, 4, 19]
      }
      expect(res).to eq(exp)
    end

    it '#[names] returns a subset of columns' do
      df.columns[:c] = data[:a]
      expect(df[:a, :b]).to eq(data)
    end

    it '#[ingeres and names] returns a subset on rows and columns' do
      df.columns[:c] = data[:a]
      expect(df[1..2, :c, :b]).to eq({ c: [1, 2], b: [18, 17] })
    end

    it '#[:undefined_column] raises error' do
      expect { df[:undefined, :undef] }.to raise_error(IndexError)
    end

    it '#[0,999] raises error' do
      expect { df[0, 99] }.to raise_error(IndexError)
    end

    it '#[5..] works with endless array' do
      expect(df[5..]).to eq(data.transform_values { |v| v[5..] })
    end
  end

  describe '#[]= two-dimensional setting' do
    it '[0] = 1, sets values on row' do
      df[0] = 1
      expect(df[0].values).to eq([1, 1])
    end

    it '[0] = [...] sets multiple values' do
      df[0] = 1, 2
      expect(df[0].values).to eq([1, 2])
      df[0] = [2, 1]
      expect(df[0].values).to eq([2, 1])
    end

    it '[0] = [...] raises error on too many values' do
      expect { df[0] = 1, 2, 3 }.to raise_error(ArgumentError)
    end

    it '[nil, :a] = 1 sets column to constant' do
      df[:a] = 1
      expect(df[:a]).to eq([1] * df[:a].size)
    end

    it '[nil, :c] = 1 sets a new column to constant' do
      df[:c] = 1
      expect(df[:c]).to eq([1] * df[:a].size)
    end

    it '[nil, :a] = [...] sets column to array' do
      df[:a] = data[:b]
      expect(df[:a]).to eq(data[:b])
    end

    it '[nil, :a] = [...] raises error on incmpatiple array' do
      expect { df[:a] = 1, 2 }.to raise_error(ArgumentError)
    end

    it '[0,:col] = constant sets single point' do
      df[0, :a] = 1
      expect(df[0, :a]).to eq(1)
    end

    it '[range,:col] = constant sets range on column' do
      df[0..2, :a] = 1
      expect(df[0..2, :a]).to eq([1] * 3)
      df[0..2, 3, :a] = 2
      expect(df[0..3, :a]).to eq([2] * 4)
    end

    it '[range,:col] = array sets an array on column' do
      df[0..2, :a] = 3, 2, 1
      expect(df[0..2, :a]).to eq([3, 2, 1])
      df[0..2, 3, :a] = [3, 2, 1, 0]
      expect(df[0..3, :a]).to eq([3, 2, 1, 0])
    end

    it '[range,:col] = array raises error on badly dimensioned array' do
      expect { df[0..1, :a] = 5, 6, 8, 9 }.to raise_error(ArgumentError)
    end

    it '[nil,columns] = constant set entire columns' do
      df[:a] = nil
      expect(df[:a]).to eq([nil] * data[:a].size)

      df[:a, :b] = 2
      expect(df[:a]).to eq([2] * data[:a].size)
      expect(df[:b]).to eq([2] * data[:a].size)
    end

    it '[nil,columns] = array set entire columns' do
      df[:a] = extra_col
      expect(df[:a]).to eq(extra_col)

      df[:a, :b] = extra_col
      expect(df[:a]).to eq(extra_col)
      expect(df[:b]).to eq(extra_col)
    end

    it '[nil,columns] = array raises error on badly dimensioned array' do
      expect { df[:a] = [1, 2] }.to raise_error(ArgumentError)
    end

    it '[rows] = constant sets some rows' do
      df[0, 1, 3..4] = nil
      [0, 1, 3, 4].each do |i|
        expect(df.row_at(i).values).to eq([nil, nil])
      end
    end

    it '[rows, cols] = constant sets values on subset' do
      df[1..2,:a, :b] = nil
      expect(df[:a][1..2]).to eq([nil, nil])
      expect(df[:b][1..2]).to eq([nil, nil])
    end

    it '[rows, cols] = array raises error on badly dimensioned array' do
      expect { df[1..2, :a, :b] = [nil] * 3 }.to raise_error(ArgumentError)
    end

    it '[rows, cols] = constnat raises error on out of index rows' do
      expect { df[1, 32, :a, :b] = [nil] * 3 }.to raise_error(IndexError)
    end
  end

  describe 'selecting rows' do
    it '#select returns new data_frame' do
      res = df.select do |row|
        (row.a < 3) || (row.b < 3)
      end
      expect(res).to_not eq(df)
      expect(df.dim).to eq([20, 2])
      expect(res.dim).to eq([6, 2])
      expect(res).to eq(df[..2, 17..])
    end

    it '#select! subsets the data_frame' do
      res = df.select! do |row|
        (row.a < 3) || (row.b < 3)
      end
      exp = {
        a: data[:a].values_at(*[..2, 17..]),
        b: data[:b].values_at(*[..2, 17..])
      }
      expect(res).to equal(df)
      expect(res).to eq(exp)
    end

    it '#reject returns new data_frame' do
      res = df.reject do |row|
        (row.a < 3) || (row.b < 3)
      end
      expect(res).to_not eq(df)
      expect(df.dim).to eq([20, 2])
      expect(res.dim).to eq([14, 2])
      expect(res).to eq(df[3..16])
    end

    it '#reject! subsets the data_frame' do
      res = df.reject! do |row|
        (row.a < 3) || (row.b < 3)
      end
      expect(res).to equal(df)
      exp = {
        a: data[:a].values_at(3..16),
        b: data[:b].values_at(3..16)
      }
      expect(res).to eq(exp)
    end

    it '#delete_at! :col deletes column' do
      df.delete_at! :a
      expect(df.column_names).to eq([:b])
    end

    it '#delete_at! rows, :col deletes column and rows' do
      df.delete_at! 0, :a
      expect(df.dim).to eq([19, 1])
    end

    it '#delete_at! range deletes rows' do
      df.delete_at! 0..2
      expect(df.dim).to eq([17, 2])
    end
  end

  describe 'sorting' do
    it '#sort by column' do
      res = df.sort :b
      expect(res).to_not equal(df)
      expect(res).to_not eq(df)
      expect(res[:b]).to eq(0..19)
    end

    it '#sort! by column and mutates' do
      res = df.sort! :b
      expect(res).to equal(df)
      expect(res[:b]).to eq(0..19)
    end

    it '#sort accepts mulitple columns and kwargs' do
      df.sort! :b, :a, asc: false
      expect(df[:a]).to eq(data[:b])
      expect(df[:b]).to eq(data[:a])
    end

    it '#sort_by! rows' do
      res = df.sort_by!(&:b)
      expect(res).to equal(df)
      expect(df[:b]).to eq(data[:a])
    end

    it '#reverse' do
      res = df.reverse
      expect(df).to_not equal(res)
      expect(res[:a]).to eq(data[:b])
    end

    it '#reverse!' do
      res = df.reverse!
      expect(df).to equal(res)
      expect(res[:a]).to eq(data[:b])
    end
  end

  describe 'conversion' do
    it '#to_a' do
      expect(df.to_a.all? { |row| row.size == df.ncol } || df.to_a.size == df.nrow).to be(true)
    end

    it '#to_s' do
      expect(df.to_s).to be_instance_of(String)
      expect(df.to_s.count("\n")).to be(df.nrow + 1)
    end

    it '#to_h' do
      expect(df.to_h).to eq(df.columns.to_h)
    end

    it '#to_hashes returns array of hashes' do
      exp = data.values.transpose.map do |row|
        data.keys.zip(row).to_h
      end
      expect(df.to_hashes).to eq(exp)
    end

    it '#to_json' do
      json = df.to_json
      bools = [
        (json.count('a') == df.nrow),
        (json.count('b') == df.nrow),
        (json.count(':') == df.nrow * 2)
      ]
      expect(json).to be_instance_of(String)
      expect(bools.all?).to be(true)
    end

    it '#as_yaml' do
      yaml = df.to_yaml
      bools = [
        (yaml.count('a') == df.nrow),
        (yaml.count('b') == df.nrow),
        (yaml.count('-') == df.nrow + 3),
        (yaml.count("\n") == df.nrow * 2 + 1)
      ]
      expect(yaml).to be_instance_of(String)
      expect(bools.all?).to be(true)
    end

    describe '#to_sql_insert' do
      it 'type: :ignore' do
        sql = df.to_sql_insert 'table', type: :ignore
        bools = [
          (sql =~ /INSERT IGNORE INTO `table`/) == 0,
          (sql =~ /(`a`, `b`)/) > 0,
          (sql =~ /VALUES/) > (sql =~ /(`a`, `b`)/),
          (sql =~ /;/) == sql.size - 1
        ]
        expect(bools.all?).to be(true)
      end

      it 'type: :update' do
        sql = df.to_sql_insert 'table', type: :update, primary_keys: [:a]
        bools = [
          (sql =~ /INSERT INTO `table`/) == 0,
          (sql =~ /(`a`, `b`)/) > 0,
          (sql =~ /VALUES/) > (sql =~ /(`a`, `b`)/),
          (sql =~ /ON DUPLICATE KEY UPDATE/) > (sql =~ /VALUES/),
          (sql =~ /;/) == sql.size - 1
        ]
        expect(bools.all?).to be(true)
      end

      it 'type: :update raises error if no :primary_keys' do
        expect { df.to_sql_insert 'table', type: :update }.to raise_error(ArgumentError)
      end

      it 'type: :insert' do
        sql = df.to_sql_insert 'table'
        bools = [
          (sql =~ /INSERT INTO `table`/) == 0,
          (sql =~ /(`a`, `b`)/) > 0,
          (sql =~ /VALUES/) > (sql =~ /(`a`, `b`)/),
          (sql =~ /;/) == sql.size - 1
        ]
        expect(bools.all?).to be(true)
      end
    end
  end

  describe 'algebra' do
    let :dfa do
      Arche::DataFrame.new(
        a: (1..4).map(&:to_f),
        b: (1..4).map(&:to_f).reverse
      )
    end

    let :dfb do
      Arche::DataFrame.new(
        a: (1..4).map(&:to_f).map(&:-@),
        b: (1..4).map(&:to_f).map(&:-@).reverse
      )
    end

    it 'can return row sums' do
      expect(dfa.map(&:sum)).to eq([5.0] * 4)
    end

    {
      :+ => 'add!',
      :- => 'subtract!',
      :* => 'mult!',
      :/ => 'divide!',
      :** => 'power!',
      :% => 'modulo!'
    }.each do |operand, banged|
      describe operand.to_s do
        let :exp_data do
          dfa.to_a.each_with_index.map do |row, index|
            row.zip(dfb.to_a[index]).map { |a, b| a.send(operand, b) }
          end
        end

        let :constantized do
          dfa.to_a.map do |row|
            row.map { |v| v.send(operand, 1) }
          end
        end

        let :operated do
          dfa.send(operand, dfb)
        end

        let :changed do
          dfa.send(banged, dfb)
        end

        it 'returns new DataFrame' do
          expect(operated).to_not equal(dfa)
        end

        it 'computes correct values' do
          expect(operated.to_a).to eq(exp_data)
        end

        it 'can operate with a constant' do
          expect(dfa.send(operand, 1).to_a).to eq(constantized)
        end

        it "#{banged} mutates self" do
          expect(changed).to equal(dfa)
        end

        it "#{banged} == #{operand}" do
          expect(operated).to eq(changed)
        end
      end
    end
  end

  describe 'MISC' do
    it '#first, returns first row' do
      expect(Arche::DataFrame.new.first).to be(nil)
      expect(df.first).to eq({ a: 0, b: 19 })
    end

    it '#last, returns first last' do
      expect(Arche::DataFrame.new.last).to be(nil)
      expect(df.last).to eq({ a: 19, b: 0 })
    end

    describe '#<<, append' do
      it 'Can append a hash' do
        hash = { a: 20, b: -1, c: 8 }
        df << hash
        expect(df.dim).to eq([21, 3])
        expect(df.last).to eq(hash)
      end

      it 'can appen unarry hash' do
        hash = {c: [8, 3]}
        df << hash
        expect(df.dim).to eq([22, 3])
        expect(df.last).to eq({ a: nil, b: nil, c: 3 })
      end

      it 'can append data_frame' do
        df << Arche::DataFrame.new(a: 4)
        expect(df.dim).to eq([21, 2])
        expect(df.last).to eq({ a: 4, b: nil })
      end

      it 'can append array of hashes' do
        df << [{ a: 9, b: 10 }, { c: 11, a: 2 }]
        expect(df.dim).to eq([22, 3])
        expect(df.last).to eq({ a: 2, b: nil, c: 11})
      end

      it 'can append array of arrays' do
        df << [[1,2],[3,4]]
        expect(df.dim).to eq([22, 2])
        expect(df.last).to eq({ a: 3, b: 4 })
      end
    end

    describe 'grouping' do
      let :data do
        {
          name: %w[Mari Stepan Henrik Marine Henrik Vartouhi Anush Voski Artur Karen'],
          sex: %i(male male male female male male female female male female),
          age: [30, 10, 85, 81, 85, 83, 81, 32, nil, 89],
          date: %w[1987-08-19 1976-04-20 1988-12-22 1969-08-11 1981-11-29 1966-08-06 2007-01-07 2005-12-24 1959-03-08 1982-03-17].map { |d| Date.parse(d) },
          income: [28.12, 1825.78, nil, 1649.88, 3084.74, 1608.0, 31.42, nil, 38.72, 4107.84]
        }
      end

      let :df do
        Arche::DataFrame.new(**data)
      end

      it '#group_indexes, returns indexes on groupings' do
        hash = df.group_indexes do |row|
          row.sex
        end
        exp = {
          male: [0, 1, 2, 4, 5, 8],
          female: [3, 6, 7, 9]
        }
        expect(hash).to eq(exp)
      end

      it '#group_indexes, takes column_name as grouping variable' do
        hash = df.group_indexes(:sex)
        exp = {
          male: [0, 1, 2, 4, 5, 8],
          female: [3, 6, 7, 9]
        }
        expect(hash).to eq(exp)
      end

      it '#group_indexes, takes column_names as grouping variable' do
        hash = df.group_indexes(:sex, :age)
        exp = {
          [:male, 30] => [0],
          [:male, 10] => [1],
          [:male, 85] => [2, 4],
          [:female, 81] => [3, 6],
          [:male, 83] => [5],
          [:female, 32] => [7],
          [:male, nil] => [8],
          [:female, 89] => [9]
        }
        expect(hash).to eq(exp)
      end

      it '#group_by, returns groupings of DataFrames' do
        hash = df.group_by { |row| row.sex }
        expect(hash.keys).to eq(%i(male female))
        expect(hash.values.first.dim).to eq([6, 5])
        expect(hash.values.last.dim).to eq([4, 5])
      end

      it '#group_by, allows grouping by keys' do
        hash = df.group_by(:sex)
        expect(hash.keys).to eq(%i(male female))
        expect(hash.values.first.dim).to eq([6, 5])
        expect(hash.values.last.dim).to eq([4, 5])
      end

    end

    describe '#merge' do
      let :dfa do
        Arche::DataFrame.new(
          country: ['UG', 'UK', 'UK', 'DK', 'DK', 'USA', 'USA', 'NO'],
          gdb:     [   0,    1,    2,    3,    4,     5,     6,    7],
          date:    [   0,    1,    2,    3,    4,     5,     6,    7],
        )
      end

      let :dfb do
        Arche::DataFrame.new(
          country: ['FR', 'UK', 'JP', 'DK',  'DK', 'USA'],
          gni:     [   8,    9,   10,   11,    12,    13],
          date:    [   0,    2,    3,    3,     4,     6],
        )
      end

      [
        [
          :country,
          :inner,
          [8, 5],
          {
            :country => ["UK", "UK", "DK", "DK", "DK", "DK", "USA", "USA"],
            :gdb => [1, 2, 3, 3, 4, 4, 5, 6],
            :date => [1, 2, 3, 3, 4, 4, 5, 6],
            :gni => [9, 9, 11, 12, 11, 12, 13, 13],
            :date2 => [2, 2, 3, 4, 3, 4, 6, 6]
          }
        ],
        [
          :country,
          :left,
          [10, 5],
          {
            :country => ["UG", "UK", "UK", "DK", "DK", "DK", "DK", "USA", "USA", "NO"],
            :gdb => [0, 1, 2, 3, 3, 4, 4, 5, 6, 7],
            :date => [0, 1, 2, 3, 3, 4, 4, 5, 6, 7],
            :gni => [nil, 9, 9, 11, 12, 11, 12, 13, 13, nil],
            :date2 => [nil, 2, 2, 3, 4, 3, 4, 6, 6, nil]
          }
        ],
        [
          :country,
          :outer,
          [12, 5],
          {
            :country => ["UG", "UK", "UK", "DK", "DK", "DK", "DK", "USA", "USA", "NO", "FR", "JP"],
            :gdb => [0, 1, 2, 3, 3, 4, 4, 5, 6, 7, nil, nil],
            :date => [0, 1, 2, 3, 3, 4, 4, 5, 6, 7, nil, nil],
            :gni => [nil, 9, 9, 11, 12, 11, 12, 13, 13, nil, 8, 10],
            :date2 => [nil, 2, 2, 3, 4, 3, 4, 6, 6, nil, 0, 3]
          }
        ],
        [
          %i(country date),
          :inner,
          [4, 4],
          {
            :country => ["UK", "DK", "DK", "USA"],
            :date => [2, 3, 4, 6],
            :gdb => [2, 3, 4, 6],
            :gni => [9, 11, 12, 13]
          }
        ],
        [
          %i(country date),
          :left,
          [8, 4],
          {
            :country => ["UG", "UK", "UK", "DK", "DK", "USA", "USA", "NO"],
            :date => [0, 1, 2, 3, 4, 5, 6, 7],
            :gdb => [0, 1, 2, 3, 4, 5, 6, 7],
            :gni => [nil, nil, 9, 11, 12, nil, 13, nil]
          }
        ],
        [
          %i(country date),
          :outer,
          [10, 4],
          {
            :country => ["UG", "UK", "UK", "DK", "DK", "USA", "USA", "NO", "FR", "JP"],
            :date => [0, 1, 2, 3, 4, 5, 6, 7, 0, 3],
            :gdb => [0, 1, 2, 3, 4, 5, 6, 7, nil, nil],
            :gni => [nil, nil, 9, 11, 12, nil, 13, nil, 8, 10]
          }
        ]
      ].each do |by, how, dim, data|
        it "merges #{how} with #{[*by].size} columns" do
          dfb.columns.rename(date: :date2) unless by.is_a?(Array)
          merged = dfa.merge(dfb, by: by, how: how)
          expect(merged.dim).to eq(dim)
          expect(merged).to eq(data)
        end
      end

      context 'with empty data_frame' do
        let :dfb do
          Arche::DataFrame.new country: []
        end

        it 'returns a new data_frame' do
          merged = dfa.merge(dfb, by: :country)
          expect(merged).to be_instance_of(Arche::DataFrame)
          expect(merged).to_not equal(dfa)
          expect(merged.ncol).to equal(dfa.ncol)
        end

        it 'does not mutatate left nor right' do
          copy_a = dfa.clone
          copy_b = dfb.clone
          merged = dfa.merge(dfb, by: :country)

          expect(merged).to_not equal(dfa)
          expect(merged).to_not equal(dfb)
          expect(dfa).to eq(copy_a)
          expect(dfb).to eq(copy_b)
        end

        it 'returns empty data_frame on inner' do
          merged = dfa.merge(dfb, by: :country, how: :inner)
          expect(merged.dim).to eq([0, 0])
        end

        it 'returns left data_frame on left' do
          merged = dfa.merge(dfb, by: :country, how: :left)
          expect(dfa).to eq(merged)
        end

        it 'returns left data_frame on outer' do
          merged = dfa.merge(dfb, by: :country, how: :outer)
          expect(dfa).to eq(merged)
        end
      end
    end
  end
end
