# kenrick_csv

kenrick_csv is a Ruby gem designed to efficiently extract and process data from CSV files based on user-defined queries.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kenrick_csv'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install kenrick_csv
```

## Usage

Require the gem and use the provided query_csv method:

```ruby
require 'kenrick_csv'

results = KenrickCSV.query_csv('path/to/file.csv', { 'Name' => 'John', 'Age' => '30' })
puts results
```

The `query_csv` method takes in the CSV file path and a query hash where the keys represent the column headers and the values are the expected values for matching rows. It returns an array of hashes for rows that match all the criteria.

## Error Handling

- If the file is not found, a message is printed to the console.
- If an error occurs during CSV processing, it is captured and a message is printed.

## Dependencies

- Ruby (>= 2.3.0)
- CSV (built-in Ruby library)

## Development

To contribute, fork the repository, make your changes, and submit a pull request.

## License

MIT License
