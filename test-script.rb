require 'benchmark'
require 'csv'
require 'parallel'
require 'terminal-table'
require 'colorize'
require 'optparse'
require 'json'
require 'fileutils'
require 'timeout'

# Configuration options with defaults
OPTIONS = {
  parallel: true,
  max_processes: 3,
  iterations: 5,
  cache_results: true,
  verbose: true,
  output_format: 'table', # 'table', 'json', or 'both'
  test_sizes: ['very_small', 'small', 'medium', 'large'],
  cache_file: 'benchmark_cache.json'
}.freeze

# Define the datasets with absolute paths
DATASETS = {
  very_small: File.expand_path('./data/100_data.csv', __dir__),
  small: File.expand_path('./data/10k_data.csv', __dir__),
  medium: File.expand_path('./data/medium_data.csv', __dir__),
  large: File.expand_path('./data/large_data.csv', __dir__)
}

# Define multiple queries to test
QUERIES = [
  { 'Name' => 'Alice' },
  { 'Name' => 'Alice', 'Age' => '25' },
  { 'Location' => 'New York', 'Occupation' => 'Engineer' }
]

# Parse command line arguments
def parse_options
  options = OPTIONS.dup
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby test-script.rb [options]"

    opts.on("-p", "--[no-]parallel", "Run tests in parallel") { |v| options[:parallel] = v }
    opts.on("-n", "--processes N", Integer, "Maximum number of parallel processes") { |v| options[:max_processes] = v }
    opts.on("-i", "--iterations N", Integer, "Number of test iterations") { |v| options[:iterations] = v }
    opts.on("-c", "--[no-]cache", "Cache results") { |v| options[:cache_results] = v }
    opts.on("-v", "--[no-]verbose", "Verbose output") { |v| options[:verbose] = v }
    opts.on("-f", "--format FORMAT", "Output format (table/json/both)") { |v| options[:output_format] = v }
    opts.on("-s", "--sizes x,y,z", Array, "Dataset sizes to test") { |v| options[:test_sizes] = v }
  end.parse!

  options
end

# Cache handling
def load_cache(cache_file)
  return {} unless File.exist?(cache_file)
  JSON.parse(File.read(cache_file))
rescue JSON::ParserError
  {}
end

def save_cache(cache_file, results)
  File.write(cache_file, JSON.pretty_generate(results))
end

# Memory usage monitoring
def memory_usage
  `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
end

def log_memory_usage(phase)
  puts "Memory usage after #{phase}: #{memory_usage.round(2)} MB".yellow if OPTIONS[:verbose]
end

# Progress bar
def progress_bar(current, total, width = 50)
  progress = current.to_f / total
  filled = (progress * width).round
  empty = width - filled
  bar = "=" * filled + " " * empty
  printf("\rProgress: [%s] %.1f%%", bar, progress * 100)
end

# Enhanced test execution with timeouts and retries
def run_single_test(gem_class, file, query, max_retries = 3)
  retries = 0
  begin
    Timeout.timeout(300) do  # 5-minute timeout
      result_size = nil
      time = Benchmark.measure do
        result = gem_class.query_csv(file, query)
        result_size = result.size
      end
      [time.real, result_size]
    end
  rescue Timeout::Error
    puts "Test timed out, retrying...".red if OPTIONS[:verbose]
    retries += 1
    retry if retries < max_retries
    [Float::INFINITY, 0]
  rescue StandardError => e
    puts "Error in test: #{e.message}".red if OPTIONS[:verbose]
    retries += 1
    retry if retries < max_retries
    [Float::INFINITY, 0]
  end
end

# Enhanced results analysis
def analyze_results(results)
  analysis = {}

  results.each do |gem_name, data|
    analysis[gem_name] = {
      average_performance: {},
      improvement_ratio: {},
      memory_usage: {},
      reliability: {}
    }

    DATASETS.keys.each do |size|
      next unless data[size]

      times = data[size][:times]
      analysis[gem_name][:average_performance][size] = times.sum / times.size
      analysis[gem_name][:reliability][size] = calculate_reliability(times)
    end
  end

  analysis
end

def calculate_reliability(times)
  return 0.0 if times.empty?

  mean = times.sum / times.size
  variance = times.map { |t| (t - mean) ** 2 }.sum / times.size
  coefficient_of_variation = Math.sqrt(variance) / mean

  1.0 / (1.0 + coefficient_of_variation)
end

def calculate_std_dev(values)
  return 0.0 if values.empty?
  mean = values.sum / values.size
  squared_diffs = values.map { |value| (value - mean) ** 2 }
  variance = squared_diffs.sum / values.size
  Math.sqrt(variance)
end

def test_gem(gem_path, datasets, queries, options)
  results = {}
  gem_name = File.basename(gem_path)

  puts "\nTesting #{gem_name}...".cyan if options[:verbose]

  begin
    # Install gem only once
    # install_gem(gem_path) unless gem_installed?(gem_name)

    # Load the gem
    require 'kenrick_csv'
    gem_class = KenrickCSV

    # Test each dataset
    datasets.each do |size, file|
      next unless options[:test_sizes].include?(size.to_s)

      results[size] = { times: [], row_counts: [], gem_name: gem_name }
      puts "  Testing #{size} dataset...".cyan if options[:verbose]

      # Run tests for each query and iteration
      total_tests = queries.size * options[:iterations]
      current_test = 0

      queries.each do |query|
        options[:iterations].times do |i|
          GC.start if i == 0  # Force garbage collection before first iteration

          time, row_count = run_single_test(gem_class, file, query)
          results[size][:times] << time
          results[size][:row_counts] << row_count

          current_test += 1
          if options[:verbose]
            progress_bar(current_test, total_tests)
            puts if current_test == total_tests
          end
        end
      end

      # Calculate statistics
      times = results[size][:times]
      results[size].merge!(
        avg_time: times.sum / times.size,
        min_time: times.min,
        max_time: times.max,
        std_dev: calculate_std_dev(times),
        memory_used: memory_usage
      )
    end

  rescue StandardError => e
    puts "Error testing gem #{gem_name}: #{e.message}".red
    puts e.backtrace if options[:verbose]
    results[:error] = e.message
  end

  [gem_name, results]
end

def gem_installed?(gem_name)
  Gem::Specification.find_by_name(gem_name)
rescue Gem::LoadError
  false
end

def install_gem(gem_path)
  Dir.chdir(gem_path) do
    begin
      # Build the gem silently
      system('gem build *.gemspec >/dev/null 2>&1')

      # Find and install the gem file silently
      gem_file = Dir.glob('*.gem').first
      system("gem install #{gem_file} >/dev/null 2>&1")

      # Clean up gem file
      FileUtils.rm(gem_file) if File.exist?(gem_file)

      true
    rescue StandardError => e
      false
    end
  end
end

def print_table_results(results, analysis)
  DATASETS.keys.each do |dataset_size|
    table = Terminal::Table.new do |t|
      t.title = "Benchmark Results - #{dataset_size.to_s.upcase} Dataset"
      t.headings = ['Gem', 'Avg Time (s)', 'Min Time (s)', 'Max Time (s)', 'Std Dev', 'Memory (MB)', 'Reliability']

      # Sort gems by average time for this dataset
      sorted_results = results.sort_by do |gem_name, data|
        next Float::INFINITY if data[:error] || !data[dataset_size]
        data[dataset_size][:avg_time]
      end

      sorted_results.each do |gem_name, data|
        next if data[:error] || !data[dataset_size]  # Skip if there was an error or no data for this size

        metrics = data[dataset_size]
        reliability = analysis[gem_name][:reliability][dataset_size].round(3) rescue 'N/A'

        t << [
          gem_name,
          metrics[:avg_time].round(5),
          metrics[:min_time].round(5),
          metrics[:max_time].round(5),
          metrics[:std_dev].round(5),
          metrics[:memory_used].round(2),
          reliability
        ]
      end

      # Add a note about the dataset file
      t.add_separator
      t.add_row [{value: "Dataset: #{DATASETS[dataset_size]}", colspan: 7}]
    end

    puts table
    puts "\n"  # Add space between tables
  end
end

def print_json_results(results, analysis)
  # Sanitize results to handle Infinity values
  sanitized_results = sanitize_for_json(results)
  sanitized_analysis = sanitize_for_json(analysis)

  output = {
    results: sanitized_results,
    analysis: sanitized_analysis,
    timestamp: Time.now.iso8601,
    test_parameters: {
      iterations: OPTIONS[:iterations],
      parallel: OPTIONS[:parallel],
      test_sizes: OPTIONS[:test_sizes]
    }
  }

  puts JSON.pretty_generate(output)
end

def sanitize_for_json(obj)
  case obj
  when Hash
    obj.transform_values { |v| sanitize_for_json(v) }
  when Array
    obj.map { |v| sanitize_for_json(v) }
  when Float
    if obj.infinite?
      "Infinity"  # or you could use null: nil
    else
      obj
    end
  else
    obj
  end
end

# Main execution
def main
  options = parse_options
  cache = options[:cache_results] ? load_cache(options[:cache_file]) : {}

  gems_directory = './'
  gem_paths = Dir.glob("#{gems_directory}/*").select { |path| File.directory?(path) }

  start_time = Time.now
  log_memory_usage("start")

  # Run tests
  benchmark_results = if options[:parallel]
    Parallel.map(gem_paths, in_processes: [gem_paths.size, options[:max_processes]].min) do |gem_path|
      test_gem(gem_path, DATASETS, QUERIES, options)
    end
  else
    gem_paths.map { |gem_path| test_gem(gem_path, DATASETS, QUERIES, options) }
  end

  log_memory_usage("tests completion")

  # Analyze results
  analysis = analyze_results(benchmark_results)

  # Output results
  case options[:output_format]
  when 'table'
    print_table_results(benchmark_results, analysis)
  when 'json'
    print_json_results(benchmark_results, analysis)
  else
    print_table_results(benchmark_results, analysis)
    print_json_results(benchmark_results, analysis)
  end

  # Save cache if enabled
  save_cache(options[:cache_file], benchmark_results) if options[:cache_results]

  log_memory_usage("end")
  puts "\nTotal execution time: #{Time.now - start_time} seconds".green
end

main if __FILE__ == $0
