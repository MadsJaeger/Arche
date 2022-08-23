# frozen_string_literal: true
require 'date'

RSpec.describe Arche::Row do
  let :data do
    {
      name: %w[Mari Stepan Henrik Marine Henrik Vartouhi Anush Voski Artur Karen],
      sex: %i(male male male female male male female female male female),
      age: [30, 10, 85, 81, 77, 83, 81, 32, nil, 89],
      date: %w[1987-08-19 1976-04-20 1988-12-22 1969-08-11 1981-11-29 1966-08-06 2007-01-07 2005-12-24 1959-03-08 1982-03-17].map { |d| Date.parse(d) },
      income: [28.12, 1825.78, nil, 1649.88, 3084.74, 1608.0, 31.42, nil, 38.72, 4107.84]
    }
  end

  let :numeric_df do
    Arche::DataFrame.new(**{
      float: [0.887],
      int: [5],
      wge: [0.84]
    })
  end

  let :numeric_row do
    numeric_df.row
  end

  let :df do
    Arche::DataFrame.new(**data)
  end

  let :row do
    df.row
  end

  let :nrow do
    df.nrow
  end

  let :ncol do
    df.ncol
  end

  describe '#initialize' do
    let :row do
      Arche::Row.new df
    end

    it 'with @accessors' do
      expect(row.instance_variable_get('@accessors')).to eq([])
    end

    it 'with @data_frame' do
      expect(row.instance_variable_get('@data_frame')).to equal(df)
    end

    it 'with @position=0' do
      expect(row.position).to eq(0)
    end
  end

  describe 'maintaining accessors' do
    it 'has been initialized with accessors' do
      expect(row.instance_variable_get('@accessors')).to eq(data.keys)
    end

    context '#define_column_accessor' do
      before(:each) do
        row.send('define_column_accessor', :new_accesosor)
      end

      it '@accesors include :new_accesosor' do
        expect(row.instance_variable_get('@accessors').include?(:new_accesosor)).to be(true)
      end

      it 'responds_to?(:new_accesosor)' do
        expect(row.respond_to?(:new_accesosor)).to be(true)
      end

      it 'responds_to?(:new_accesosor=)' do
        expect(row.respond_to?(:new_accesosor=)).to be(true)
      end

      it 'row.new_accesosor raises error' do
        expect { row.new_accesosor }.to raise_error(KeyError)
      end
    end

    context '#remove_column_accessor' do
      before(:each) do
        row.send('remove_column_accessor', :name)
      end

      it '@accesors exclude :removed_accessor' do
        expect(!row.instance_variable_get('@accessors').include?(:name)).to be(true)
      end

      it '!responds_to?(:removed_accessor)' do
        expect(row.respond_to?(:name)).to be(false)
      end

      it '!responds_to?(:removed_accessor=)' do
        expect(row.respond_to?(:name=)).to be(false)
      end
    end

    context '#maintain_accessors' do
      before(:each) do
        row.send('define_column_accessor', :new_accesosor)
        row.send('remove_column_accessor', :name)
        axe = row.instance_variable_get('@accessors')
        if (axe.size != data.size) || axe.include?(:name) || !axe.include?(:new_accesosor)
          raise Exception 'FAILED TEST SETUP'
        end

        row.maintain_accessors
      end

      let :accessors do
        row.instance_variable_get('@accessors')
      end

      it 'removes excessive accesors' do
        expect(accessors.include?(:new_accesosor)).to be(false)
      end

      it 'adds missing accessros' do
        expect(accessors.include?(:name)).to be(true)
      end

      it 'has union of accessors to column_names' do
        expect((accessors & df.column_names).size).to be(ncol)
      end
    end
  end

  describe 'accessing' do
    it '#values returns values from columns' do
      (-nrow..(nrow - 1)).each do |pos|
        row.position = pos
        expected = data.values.map { |arr| arr[pos] }
        expect(row.values.map { |v| v.nan? ? nil : v }).to eq(expected)
      end
    end

    describe '#values=' do
      it 'can set all to constant' do
        row.values = nil
        expect(row.values).to eq([nil] * ncol)
      end

      it 'mutates the data_frame' do
        row.values = nil
        expect(df[0, :name]).to eq(nil)
        expect(df[0].values).to eq([nil] * ncol)
      end

      it 'can replace with a new array' do
        strings = ncol.times.map { rand.to_s[0..4] }
        row.values = strings
        expect(row.values).to eq(strings)
      end

      it 'raises error when new array.sie != ncol' do
        expect { row.values = [nil] * (ncol + 1) }.to raise_error(ArgumentError)
      end
    end

    describe '#position=' do
      it 'can be changed in range -nrow..(nrow-1)' do
        (-nrow..(nrow - 1)).each do |pos|
          row.position = pos
          expect(row.position).to eq(pos)
        end
      end

      it 'raises error on < -nrow' do
        expect { row.position = -nrow - 1 }.to raise_error(IndexError)
      end

      it 'raises error on >= nrow' do
        expect { row.position = nrow }.to raise_error(IndexError)
      end
    end

    it '#[] returns its value by key' do
      data.each do |key, arr|
        arr.each_with_index do |value, index|
          row.position = index
          if row[key].nan?
            expect(value.nil?).to be(true)
          else
            expect(row[key]).to eq(value)
          end
        end
      end
    end

    it '#[] raises KeyError on undefined column' do
      expect { row[:undefined_column] }.to raise_error(KeyError)
    end

    it '#[]= sets single point' do
      (0..(nrow - 1)).each do |index|
        row.position = index
        row.column_names.each do |name|
          row[name] = nil
        end
      end
      expect(df.to_a.flatten.all?(&:nil?)).to be(true)
    end

    it '#map! transform all values' do
      res = row.map! { |val| val.to_s + 'modified' }
      exp = data.map { |_key, col|  col[0].to_s + 'modified'}
      expect(res).to eq(row.values)
      expect(row.values).to eq(exp)
    end
  end

  describe 'misc delegation' do
    it '#to_a returns values' do
      expect(row.to_a).to eq(row.values)
    end

    it '#values_at, delegates to #to_a' do
      expect(row.values_at(0)).to eq(row.to_a.values_at(0))
      expect(row.values_at(0)).to eq(['Mari'])
    end

    it '#map, delegates to #to_a' do
      expect(row.map(&:itself)).to eq(row.to_a)
    end

    it '#each, delegates to #to_a' do
      vals = []
      row.each { |v| vals << v }
      expect(vals).to eq(row.to_a)
    end

    it '#slice, delegates to #to_h' do
      expect(row.slice(:name, :age)).to eq( { name: 'Mari', age: 30 } )
    end

    it '#to_json, delegates to #to_h' do
      expect(row.to_json).to eq(row.to_h.to_json)
    end

    it '#to_yaml, delegates to #to_h' do
      expect(row.to_yaml).to eq(row.to_h.to_yaml)
    end
  end
end
