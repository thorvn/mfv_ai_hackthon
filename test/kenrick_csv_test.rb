require 'minitest/autorun'
require 'kenrick_csv'
require 'csv'
require 'tempfile'

class KenrickCSVTest < Minitest::Test
  def setup
    @tempfile = Tempfile.new(['test_data', '.csv'])
    CSV.open(@tempfile.path, 'w') do |csv|
      csv << ['Name', 'Age']
      csv << ['John', '30']
      csv << ['Alice', '25']
      csv << ['John', '25']
    end
  end

  def teardown
    @tempfile.close
    @tempfile.unlink
  end

  def test_query_csv_returns_correct_rows
    results = KenrickCSV.query_csv(@tempfile.path, { 'Name' => 'John', 'Age' => '30' })
    assert_equal 1, results.size
    assert_equal({ 'Name' => 'John', 'Age' => '30' }, results.first)
  end

  def test_query_csv_returns_empty_if_no_match
    results = KenrickCSV.query_csv(@tempfile.path, { 'Name' => 'Nonexistent', 'Age' => '30' })
    assert_equal [], results
  end

  def test_query_csv_handles_missing_file
    results = KenrickCSV.query_csv('non_existent_file.csv', { 'Name' => 'John', 'Age' => '30' })
    assert_equal [], results
  end

  def test_query_csv_with_dataset
    results = KenrickCSV.query_csv('data/100_data.csv', { 'Occupation' => 'Designer' })
    assert_equal 14, results.size
    designer_names = results.map { |row| row['Name'] }
    assert_includes designer_names, 'Divina Dibbert Ret.'
  end
end
