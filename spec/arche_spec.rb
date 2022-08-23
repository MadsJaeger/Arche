# frozen_string_literal: true

RSpec.describe Arche do
  it "has a version number" do
    expect(Arche::VERSION).not_to be nil
  end

  describe '.bound_range' do
    [
      [0, nil, 0, 10],
      [11, nil, 11, 11],
      [-2, nil, -2, -1],
      [-11, nil, -11, -1],
      [nil, 4, 0, 4],
      [nil, 11, 0, 11],
      [nil, -4, -10, -4],
      [nil, -11, -11, -11]
    ].each do |from, to, ef, et|
      it "#{from}..#{to} (max = 10)=> #{ef}..#{et}" do
        expect(Arche.bound_range( from..to, 10)).to eq(ef..et)
      end
    end
  end
end
