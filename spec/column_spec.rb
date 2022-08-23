# frozen_string_literal: true

RSpec.describe Arche::Column do
  let :data do
    {
      a: (0..9).to_a,
      b: (0..9).to_a.reverse,
      c: [nil, 0.85, 0.97, 0.38, nil, 0.24, 0.57, 0.38, 0.17, 0.32]
    }
  end

  let :df do
    Arche::DataFrame.new(**data)
  end

  let :cols do
    df.columns
  end

  describe '#initialize' do
    before(:each) do
      @df   = Arche::DataFrame.new
      @cols = df.columns

    end

    it "with an array" do
      col  = Arche::Column.new @cols, []
      expect(col).to be_instance_of(Arche::Column)
      expect(col.size).to be(0)
    end

    it 'replaces nil with NaN if floats are given' do
      @data = [nil, 7.2, nil]
      @exp  = [Float::NAN, 7.2, Float::NAN]
      col   = Arche::Column.new @cols, @data

      expect(col).to eq(@exp)
      expect(col.size).to be(@data.size)
    end
  end

  describe 'Accessing' do
    it '#[] with an integer' do
      expect(cols[:a][0]).to be(data[:a][0])
      expect(cols[:a][9]).to be(data[:a][9])
      expect(cols[:a][-1]).to be(data[:a][-1])
    end

    it '#[] cannot access with integer out of range' do
      expect{ cols[:a][10] }.to raise_error(IndexError)
      expect{ cols[:a][-11] }.to raise_error(IndexError)
    end

    it '#[] with mutliple integers' do
      expect(cols[:a][0,2,2]).to eq(data[:a].values_at(0,2,2))
    end

    it '#[] cannot access with multiple integers out of range' do
      expect{ cols[:a][10,1] }.to raise_error(IndexError)
      expect{ cols[:a][-11,5] }.to raise_error(IndexError)
    end

    it '#[] with range' do
      expect(cols[:a][0..9]).to eq(data[:a])
      expect(cols[:a][-10..-1]).to eq(data[:a])
    end

    it '#[] with endless range' do
      expect(cols[:a][(0..), 1]).to eq(data[:a] + [1])
      expect(cols[:a][..9]).to eq(data[:a])
    end

    it '#[] cannot access with range out of range' do
      expect{ cols[:a][0..10] }.to raise_error(IndexError)
      expect{ cols[:a][-11..-1] }.to raise_error(IndexError)
    end

    it '#[] ranges and integers' do
      expect(cols[:a][0..9,0,9]).to eq(data[:a]+[0,9])
    end

    it '#[] with a hash defining start and length' do
      expect(cols[:a][{ start: 2, length: 2 }]).to eq(data[:a][2, 2])
    end

    it '#[] cannot access with hash where start is out of range' do
      expect{ cols[:a][{ start: 10, length: 2 }] }.to raise_error(IndexError)
    end

    it '#values_at may return the same value multiple times' do
      expect(cols[:a].values_at(2,2,2,3)).to eq([2,2,2,3])
    end

    it '#values_at raises IndexError when out of range' do
      expect{ cols[:a].values_at(9,11) }.to raise_error(IndexError)
    end
  end

  describe 'Setting' do
    it '#[]= sets value at position' do
      expect(cols[:a][0] = -10).to be(-10)
      expect(cols[:a][0]).to be(-10)
    end

    it '#[]= raises indexerror when out of range' do
      expect{ cols[:a][10] = -10 }.to raise_error(IndexError)
      expect{ cols[:a][-11] = -10 }.to raise_error(IndexError)
    end

    it '#[indices]=constant sets value at multiple places' do
      cols[:a][[0, 4, 6..8]] = nil
      expect(cols[:a]).to eq([nil,1,2,3,nil,5,nil,nil,nil,9])
    end

    it '#[range]=constant sets value at multiple places' do
      cols[:a][0..2] = nil
      expect(cols[:a]).to eq([nil] * 3 + data[:a][3..])
    end

    it '#[indices]=array sets different values' do
      cols[:a][0..2] = (0..2).to_a.reverse
      expect(cols[:a]).to eq([2, 1 ,0] + data[:a][3..])
    end

    it '#[indices]=array raises error on incompatible dimensions' do
      expect{ cols[:a][0..2] = (0..5) }.to raise_error(ArgumentError)
    end
  end

  describe 'Has row-wise algebric operations' do
    it '#+ adds columns' do
      res = cols[:a]+cols[:b]
      expect(res).to be_instance_of(Array)
      expect(res).to eq(data[:a].zip(data[:b]).map { |a, b| a + b })
    end

    it '#+ adds arrays' do
      res = cols[:a]+data[:b]
      expect(res).to be_instance_of(Array)
      expect(res).to eq(data[:a].zip(data[:b]).map { |a, b| a + b })
    end

    it '#+ adds constants' do
      res = cols[:a]+10
      expect(res).to be_instance_of(Array)
      expect(res).to eq(data[:a].map { |a| a + 10 })
    end

    it '#add! mutates a column' do
      res = cols[:a].add!(cols[:b])
      expect(res).to be_instance_of(Arche::Column)
      expect(res).to equal(cols[:a])
      expect(res).to eq(data[:a].zip(data[:b]).map { |a, b| a + b })
    end

    it '#-, #subtract!' do
      res = cols[:a] - cols[:b]
      init = -11
      exp = 10.times.map{ init += 2}
      expect(res).to eq(exp)
      expect(cols[:a].subtract!(data[:b])).to eq(res)
    end

    it '#*, #mult!' do
      res = cols[:a] * cols[:b]
      exp = data[:a].zip(data[:b]).map { |a, b| a * b }
      expect(res).to eq(exp)
      expect(cols[:a].mult!(data[:b])).to eq(res)
    end

    it '#/, #divide!' do
      expect { cols[:a] / cols[:b] }.to raise_error(ZeroDivisionError)
      data_c = data[:c].map { |v| v.nil? ? Float::NAN : v }
      res = (cols[:a] / cols[:c]).map{ |v| v.round(6) }
      exp = data[:a].zip(data_c).map { |a, c| (a / c).round(6) }
      # Both exp and res are arrays whus we cannot do res == exp, and get true
      # but can compare a column to exp
      new_col = Arche::Column.new(cols, res)
      expect(new_col).to eq(exp)
      expect(cols[:a].divide!(data_c).round!(6)).to eq(res)
    end

    it '#%, #modulo!' do
      data_c = data[:c].map { |v| v.nil? ? Float::NAN : v}
      res = (cols[:a] % cols[:c]).map{ |v| v.round(6) }
      exp = data[:a].zip(data_c).map { |a, c| (a % c).round(6) }
      expect(res.zip(exp).all? { |a, b| (a == b) || (a.nan? && b.nan?)} ).to be(true)
      expect(cols[:a].modulo!(data_c).round!(6)).to eq(res)
    end

    it '#**, #power!' do
      res = cols[:a]**0.5
      exp = data[:a].map { |v| v**0.5 }
      expect(res).to eq(exp)
      expect(cols[:a].power!(0.5)).to eq(exp)
    end

    it '#cumulative' do
      sum = 0
      exp = data[:a].map { |v| sum += v }
      res = cols[:a].cumulative(&:+)
      alt = cols[:a].cumulative { |csum, v| csum + v }
      expect(res).to eq(alt)
      expect(res).to eq(exp)
      cols[:a].cumulative!(&:+)
      expect(cols[:a]).to eq(exp)
    end

    it '#round' do
      expect(cols[:c].round(1).all? { |v|  v.to_s.size == 3 }).to be(true)
    end

    [
      [1, [nil] + (0..8).to_a],
      [2, [nil] * 2 + (0..7).to_a],
      [-1, (1..9).to_a + [nil]],
      [-2, (2..9).to_a + [nil] * 2],
    ].each do |lag, exp|
      it "#lag(#{lag})" do
        expect(cols[:a].lag(lag)).to eq(exp)
      end
    end

    it '#lag(nrow)' do
      expect( cols[:a].lag(10) ).to eq([nil]*10)
      expect( cols[:a].lag(-10) ).to eq([nil]*10)
    end

    it '#lag(nrow + 1) raises idnex error' do
      expect { cols[:a].lag(11) }.to raise_error(IndexError)
      expect { cols[:a].lag(-11) }.to raise_error(IndexError)
    end

    it '#lag!' do
      expect(cols[:a].lag!).to eq([nil] + (0..8).to_a)
    end

    it '#diff!' do
      expect( Arche::Column.new(cols, cols[:a].diff) ).to eq([Float::NAN] + [1] * 9)
      expect( Arche::Column.new(cols, cols[:a].diff(2)) ).to eq([Float::NAN] * 2 + [2] * 8)
      expect( Arche::Column.new(cols, cols[:a].diff(-1)) ).to eq([-1] * 9 + [Float::NAN])
      expect( Arche::Column.new(cols, cols[:a].diff(-2)) ).to eq([-2] * 8 + [Float::NAN] * 2)
      expect( cols[:a].diff! ).to eq([Float::NAN] + [1] * 9)
    end
  end

  describe 'it has statistics' do
    before(:each) do
      @min = 0.17
      @max = 0.97
      @minmax = [0.17, 0.97]
      @sum = data[:c].compact.sum
      @prod = data[:c].compact.reduce(1, :*)
      @mean = data[:c].compact.sum / data[:c].compact.size
      @var = 0.08345714285714283
      @std = 0.2888894993888543
    end

    %w[min max minmax sum prod mean var std].each do |meth|
      it "##{meth}" do
        var = instance_variable_get("@#{meth}")
        expect(cols[:c].send(meth)).to eq(var)
      end
    end
  end

  describe 'converts its data' do
    [
      [:to_c, Complex],
      [:to_d, BigDecimal],
      [:to_f, Float],
      [:to_r, Rational],
      [:to_i, Integer],
      [:to_s, String],
      [:abs, Integer]
    ].each do |conv, klass|
      it "##{conv}" do
        res = cols[:a].send(conv)
        expect(res).to be_instance_of(Array)
        expect(res.all? { |v| v.instance_of?(klass) }).to be(true)
        expect(cols[:a].send("#{conv}!")).to eq(res)
      end
    end

    it '#to_a returns duplicate of data' do
      array = cols[:a].to_a
      expect(array).to be_instance_of(Array)
      expect(cols[:a]).to eq(array)
      inst_data = cols[:a].instance_variable_get("@data")
      expect(inst_data.equal?(array)).to be(false)
    end
  end

  describe 'can replace data' do
    before(:each) do
      cols[:a][0] = nil
      cols[:a][1] = Float::NAN
      cols[:a][3] = 2
    end

    it '#replace_nil!' do
      res = cols[:a].replace_nil!
      expect(res).to equal(cols[:a])
      expect(res[0].nan?).to be(true)
    end

    it '#replace_nil' do
      res = cols[:a].replace_nil
      expect(res[0].nan?).to be(true)
      expect(cols[:a][0].nil?).to be(true)
    end

    it '#replace_nan!' do
      res = cols[:c].replace_nan!
      expect(res).to equal(cols[:c])
      expect(res[0].nil?).to be(true)
    end

    it '#replace_nan' do
      res = cols[:c].replace_nan
      expect(res[0].nil?).to be(true)
      expect(cols[:c][0].nan?).to be(true)
    end

    it '#replace_values!' do
      res = cols[:a].replace_values!(**{ 2 => 10, nil => 0 })
      expect(res).to equal(cols[:a])
      expect(res[0]).to be(0)
      expect(res[2]).to be(10)
      expect(res[3]).to be(10)
    end

    it '#replace_values' do
      res = cols[:a].replace_values(**{ 2 => 10, nil => 0 })
      cols[:a].replace_values!(**{2 => 10, nil => 0})
      expect(cols[:a]).to eq(res)
    end

    it '#replace!' do
      expect((cols[:a].replace! [nil]*10).all?(&:nil?)).to be(true)
    end

    it '#replace! raises ArgumentError with incompatible data' do
      expect{ cols[:a].replace! [nil]*9 }.to raise_error(ArgumentError)
    end
  end

  describe 'can subset/select/delete/reject' do
    it '#compact returns all non nil an non nan numbers' do
      cols[:c][1] = nil
      expect(cols[:c].compact.all?).to be(true)
    end

    it '#compact! & on siblings' do
      cols[:c][1] = nil
      expect(cols[:c].compact!.all?).to be(true)
      expect(cols[:c].size).to be(7)
      expect(cols[:a]).to eq([2,3,5,6,7,8,9])
      expect(cols[:b]).to eq([7,6,4,3,2,1,0])
    end

    it '#select! & on siblings' do
      cols[:a].select! do |v|
        (v % 2) == 0
      end
      expect(cols[:a].size).to be(5)
      expect(cols[:b]).to eq([9, 7, 5, 3, 1])
      expect(cols[:c].size).to be(5)
    end

    it '#reject! & on siblings' do
      cols[:a].reject! do |v|
        (v % 2) == 0
      end
      expect(cols[:a].size).to be(5)
      expect(cols[:b]).to eq([8, 6, 4, 2, 0])
      expect(cols[:c].size).to be(5)
    end

    it '#find_indexes find indexes of all matching values' do
      expect(cols[:c].find_indexes(Float::NAN)).to eq([0,4])
    end

    it '#find_indexes find indexes of block' do
      expect(cols[:a].find_indexes { |v| (v % 2) == 0 }).to eq([0,2,4,6,8])
    end

    it '#delete removes elements equal to & on siblings' do
      cols[:a][1] = 0
      cols[:a].delete(0)
      expect(cols[:a][0]).to be(2)
      expect(cols[:b][0]).to be(7)
      expect(cols[:c][0]).to be(data[:c][2])
    end

    it '#pop removes the last row' do
      cols[:a].pop
      expect(cols[:a][-1]).to be(8)
      expect(cols[:b][-1]).to be(1)
      expect(cols[:c][-1]).to be(data[:c][-2])
    end

    it '#pop n removes the last n rows' do
      cols[:a].pop(2)
      expect(cols[:a][-1]).to be(7)
      expect(cols[:b][-1]).to be(2)
      expect(cols[:c][-1]).to be(data[:c][-3])
    end

    it '#uniq! & on siblings' do
      cols[:a][1] = 0
      cols[:a].uniq!
      expect(cols[:a][1]).to be(2)
      expect(cols[:b][1]).to be(7)
      expect(cols[:c][1]).to be(data[:c][2])
    end

    it '#select_rows_at! raises index error when out of range' do
      expect{ cols[:a].select_rows_at!(11) }.to raise_error(IndexError)
    end

    it '#select_rows_at! on duplicate entries' do
      expect(cols[:a].select_rows_at! 1, ..3, 2, 5, 1).to eq([1, 0 , 1, 2, 3, 2, 5, 1])
    end

    it '#delete_rows_at! raises index error when out of range' do
      expect{ cols[:a].delete_rows_at!(-12) }.to raise_error(IndexError)
    end

    it '#delete_rows_at! on duplicate entries' do
      expect(cols[:a].delete_rows_at! 0, 0, 0..4).to eq(5..9)
    end
  end

  describe 'can sort/rearange' do
    it '#reverse!' do
      cols[:a].reverse!
      %i(a b).each do |key|
        expect(cols[key]).to eq(data[key].reverse)
      end
      expect(cols[:c]).to eq(data[:c].reverse.map { |v| v.nil? ? Float::NAN : v } )
    end

    it '#sort! [nil_first, nil_last, asc, desc]' do
      cols[:a][5] = nil
      arr = data[:a].dup
      arr.delete_at(5)

      [true, false].repeated_permutation(2).to_a.each do |nil_first, asc|
        cols[:a].sort!(nil_first: nil_first, asc: asc)
        expect(cols[:a][0]).to be(nil) if nil_first
        expect(cols[:a][-1]).to be(nil) unless nil_first
        expect(cols[:a].compact).to eq(arr)  if asc
        expect(cols[:a].compact).to eq(arr.reverse)  unless asc
      end
    end

    it '#sort! & on siblings' do
      cols[:b].sort!
      expect(cols[:a]).to eq( (0..9).to_a.reverse )
    end

    it '#sort do not mutate' do
      res = cols[:a].sort(asc: false)
      exp = (0..9).to_a.reverse
      expect(res).to eq(exp)
      expect(cols[:b]).to eq(exp)
    end

    it '#sort_by! &block' do
      sorted = cols[:a].sort_by { |v| v % 2 }
      exp = [2, 6, 4, 8, 0, 9, 1, 3, 5, 7]
      expect(sorted).to eq(exp)
      expect(cols[:a]).to eq(data[:a])
      expect(cols[:a].sort_by! { |v| v % 2 }).to eq(exp)
    end
  end

  # misc
end
