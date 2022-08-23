# require_relative 'data_frame_mock'

RSpec.describe Arche::Columns do
  let :data do
    {
      a: (0..19).to_a,
      b: (0..19).to_a.reverse,
    }
  end

  let :df do
    Arche::DataFrame.new(**data)
  end

  let :cols do
    df.columns
  end

  let :extra_col do
    ('a'..'t').to_a
  end

  describe '#initialize' do
    it 'with no data' do
      inst = Arche::Columns.new df
      expect(inst).to be_instance_of(Arche::Columns)
    end

    it 'with a hash' do
      cols = Arche::Columns.new df, **data
      expect(cols.names).to eq(%i(a b))
      data.keys.all? do |key|
        expect(cols[key]).to eq(data[key])
      end
    end

    it 'has @data_frame' do
      expect(cols.instance_variable_get("@data_frame")).to be_instance_of(Arche::DataFrame)
    end

    it 'has @data' do
      expect(cols.instance_variable_get("@data")).to be_instance_of(Hash)
    end

    it '@data holds data' do
      @data = cols.instance_variable_get("@data")
      data.each do |k,v|
        expect(@data[k]).to eq(v)
      end
    end
  end

  describe 'it delegates' do
    it '#respond_to_missing' do
      hash_methods = {}.methods
      miss_methods = hash_methods - cols.methods
      expect(miss_methods.all? { |meth| cols.send(:respond_to_missing?, meth) }).to be(true)
    end

    it '#method_missing' do
      # one? is a column
      hash_methods = {}.methods
      miss_methods = hash_methods - cols.methods
      expect(miss_methods.include? :one?).to be(true)
      expect(cols.one?).to be(false)
    end

    it '#def_delegators' do
      # keys has been delegated
      expect(cols.keys).to eq(data.keys)
    end

    it 'responds_to #names #ncol #columns (aliases)' do
      %i(names ncol columns).each do |key|
        expect(cols.respond_to? key).to be(true)
      end
    end

    it 'cannot #repalce #transform_keys! #transform_values' do
      %i(replace transform_keys! transform_values!).all? do |key|
        expect { cols.send(key) }.to raise_error(Arche::MutationError)
      end
    end
  end

  describe '#[]' do
    it 'returns array' do
      expect(cols[:a, :b]).to be_instance_of(Array)
    end

    it 'with one index returns column' do
      expect(cols[:a]).to be_instance_of(Arche::Column)
    end

    it 'with names' do
      expect(cols[:a, :b]).to eq(data.values_at(:a, :b))
      expect(cols[:a]).to eq(data[:a])
    end

    it 'raises TypeError on bad names' do
      expect { cols[:m] }.to raise_error(KeyError)
    end

    it 'raises KeyError on integer' do
      expect { cols[10] }.to raise_error(KeyError)
    end
  end

  describe '#[]=' do
    it 'sets Arche::Column' do
      cols[:c] = extra_col
      expect(cols[:c]).to be_instance_of(Arche::Column)
    end

    it 'holds given data' do
      cols[:c] = extra_col
      expect(cols[:c]).to eq(extra_col)
    end

    it 'can set from a single object' do
      cols[:c] = nil
      expect(cols[:c]).to eq([nil] * data[:a].size)
    end

    it 'can set string names' do
      cols['c'] = extra_col
      expect(cols.key?('c')).to be(true)
    end

    it 'cannot set integer names' do
      expect { cols[1] = extra_col }.to raise_error(ArgumentError)
    end

    it 'cannot set columns at a different size' do
      expect { cols[1] = [1, 2] }.to raise_error(ArgumentError)
    end

    it 'its parent @data_frame has no accessor before set' do
      expect(df.row.respond_to?(:c)).to be(false)
    end

    it 'setting a new column adds accessor on @data_frame.row' do
      cols[:c] = extra_col
      expect(df.row.respond_to?(:c)).to be(true)
    end

    it '#set with key words' do
      cols.set(c: extra_col, d: extra_col)
      expect(cols.key? :c).to be(true)
      expect(cols.key? :d).to be(true)
    end

    it '#set with string' do
      cols.set(**{ c: extra_col, 'd' => extra_col })
      expect(cols.key? :c).to be(true)
      expect(cols.key? 'd').to be(true)
    end
  end

  describe 'mutations' do
    it '#rename' do
      cols.rename a: :c, b: :d
      expect(cols.keys).to eq(%i(c d))
      expect(cols[:c]).to eq(data[:a])
      expect(cols[:d]).to eq(data[:b])
      expect(df.row.respond_to? :a).to be(false)
      expect(df.row.respond_to? :c).to be(true)
      expect(df.row.respond_to? :b).to be(false)
      expect(df.row.respond_to? :d).to be(true)
    end

    it '#rename raises ArgumentError on bad names' do
      expect { cols.rename a: 1 }.to raise_error(ArgumentError)
    end

    it '#delete' do
      expect(cols.delete :a, :b, :c).to eq( data.values_at(:a, :b) + [nil])
      expect(cols.nrow).to be(0)
      expect(cols.ncol).to be(0)
      expect(df.row.respond_to? :a).to be(false)
      expect(df.row.respond_to? :b).to be(false)
    end

    it '#delete_if' do
      cols.delete_if { |k,v| (k == :a) || (v[0] == 19) }
      expect(cols.nrow).to be(0)
      expect(cols.ncol).to be(0)
      expect(df.row.respond_to? :a).to be(false)
      expect(df.row.respond_to? :b).to be(false)
    end

    it '#select_rows_at! subsets all columns to indices' do
      cols.select_rows_at! 0, -1
      expect(cols[:a]).to eq([0, 19])
      expect(cols[:b]).to eq([19, 0])
    end

    it '#slice returns new instance' do
      subset = cols.slice :a, :b
      expect(cols).to_not equal(subset)
      expect(cols).to eq(subset)
    end

    it '#slice! returns new instance' do
      subset = cols.slice :a, :b
      expect(cols).to_not equal(subset)
      expect(cols).to eq(subset)
    end

    it '#slice! subsets columns' do
      cols.slice! :a
      expect(cols.keys).to eq([:a])
      expect(df.row.respond_to? :b).to be(false)
    end

    it '#merge returns columns' do
      res = cols.merge({ c: extra_col })
      expect(res).to be_instance_of(Arche::Columns)
      expect(res).to eq(data.merge({ c: extra_col }))
      expect(res).to_not equal(cols)
    end

    it '#merge raises argument error on incompatible hash' do
      expect { cols.merge({ c: 2 }) }.to raise_error(ArgumentError)
    end

    it '#merge! mutates self' do
      res = cols.merge!({ c: extra_col })
      expect(res).to eq(data.merge({ c: extra_col }))
      expect(res).to equal(cols)
    end

    it '#sort returns sorted hash' do
      expect(cols.sort).to eq(data)
    end

    it '#sort! sorts columns by name' do
      df = Arche::DataFrame.new b: 1, a: 1
      df.columns.sort!
      expect(df.columns.names ).to eq(%i(a b))
    end
  end

  describe 'misc actions' do
    it '#==' do
      expect(cols).to_not eq(1)
      expect(cols).to_not eq(Object.new)
      expect(cols).to_not eq({})
      expect(cols).to_not eq([])
      expect(cols).to_not eq([:a, :b])
      expect(cols).to_not eq(data.to_a)
      expect(cols).to eq(data)
    end

    it 'nrow' do
      expect(cols.nrow).to eq(20)
    end

    it '#ncol' do
      expect(cols.ncol).to eq(2)
    end

    it '#dim' do
      expect(cols.dim).to eq([20, 2])
    end

    it '#to_h returns a duplicate of its data' do
      res = cols.to_h
      expect(res).to eq(data)
      expect(cols).to eq(res)
      expect(res).to_not equal(cols.instance_variable_get('@data'))
    end

    it '#to_a returns columsn as arrays' do
      res = cols.to_a
      expect(res.size).to eq(2)
      expect(res[0][1]).to be_instance_of(Array)
    end
  end
end
