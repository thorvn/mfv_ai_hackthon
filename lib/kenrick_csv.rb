require "csv"
require_relative "kenrick_csv/version"

module KenrickCSV
  def self.query_csv(file_path, query_hash)
    results = []
    begin
      CSV.foreach(file_path, headers: true) do |row|
        if query_hash.all? { |header, value| row[header] == value }
          results << row.to_hash
        end
      end
    rescue Errno::ENOENT
      puts "File not found: #{file_path}"
      return []
    rescue Exception => e
      puts "Error processing CSV: #{e.message}"
      return []
    end
    results
  end
end
