# Arche

Providing Arche::DataFrame for DataFrame semantics like Pythons pandas or R's core data.frame object. A DataFrame may be useful for your procedural data operations, or for implementing statistics, econometrics, data-science and similar.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'arche'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install arche

## Usage

See Arche::DataFrame for full documentation of its usage. It can basically be accessed by:

```ruby
# Initializing
df = Arche::DataFrame.new a: 0..9, b: (0..9).to_a.reverse
# =>
# Arche::DataFrame (10,2)
#   a   b
# --- ---
#   0   9
#   1   8
#   2   7
#   3   6
#   4   5
#   5   4
#   6   3
#   7   2
#   8   1
#   9   0

# ACCESSING:
# df[integers_or_ranges_for_rows, symbols_for_columns]
# point
df[5,:a] # => 5
# column
df[:a] # => #<Arche::Column [0, 1, 2, ...]>
# row
df[0] # => <Arche::Row {:a=>0, :b=>9}>
# columns
df[:a,:b]
# =>
# Arche::DataFrame (10,2)
#   a   b
# --- ---
#   0   9
#   1   8
#   2   7
#   3   6
#   4   5
#   5   4
#   6   3
#   7   2
#   8   1
#   9   0

# rows
df[3..5]
# =>
# Arche::DataFrame (3,2)
# a   b
# --- ---
# 3   6
# 4   5
# 5   4
```

A wide range of Rubys core method works on a DataFrame instance:

```ruby
df.select { |row| row.a >  5 }
# =>
# Arche::DataFrame (4,2)
#   a   b
# --- ---
#   6   3
#   7   2
#   8   1
#   9   0

df.reject!{ |row| row.b < 4}
# =>
# Arche::DataFrame (6,2)
#   a   b
# --- ---
#   0   9
#   1   8
#   2   7
#   3   6
#   4   5
#   5   4
```

And algebra works out of the box:

```ruby
df.columns = { c: df[:a] + df[:b] }
# => {:c=>[9, 9, 9, 9, 9, 9]}
df
# =>
# Arche::DataFrame (6,3)
#   a   b   c
# --- --- ---
#   0   9   9
#   1   8   9
#   2   7   9
#   3   6   9
#   4   5   9
#   5   4   9
```

You may sort on columns:

```ruby
df.sort!(:b)
# =>
# Arche::DataFrame (6,3)
#  a   b   c
# --- --- ---
#  5   4   9
#  4   5   9
#  3   6   9
#  2   7   9
#  1   8   9
#  0   9   9
```

And merge onto other data:


```ruby
odf = Arche::DataFrame.new b: 4..9, c: 6.times.map{ rand }, d: ('a'..'f' ).to_a
# =>
# Arche::DataFrame (6,3)
#   b                   c   d
# --- ------------------- ---
#   4  0.8764110250115325   a
#   5  0.8229292514288494   b
#   6 0.06127556196125328   c
#   7  0.9700396775720521   d
#   8  0.5878504004583608   e
#   9  0.3469167032308601   f
> df.merge(odf, by: :b)
# =>
# Arche::DataFrame (6,4)
#   b   a                   c   d
# --- --- ------------------- ---
#   4   5  0.8764110250115325   a
#   5   4  0.8229292514288494   b
#   6   3 0.06127556196125328   c
#   7   2  0.9700396775720521   d
#   8   1  0.5878504004583608   e
#   9   0  0.3469167032308601   f
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/madshjaeger/arche. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/madshjaeger/arche/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Arche project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/madshjaeger/arche/blob/master/CODE_OF_CONDUCT.md).
