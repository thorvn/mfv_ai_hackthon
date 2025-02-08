Gem::Specification.new do |spec|
  spec.name          = "kenrick_csv"
  spec.version       = '0.1.0'
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = %q{A Ruby gem to extract and process CSV data based on queries.}
  spec.description   = %q{KenrickCSV provides efficient extraction and processing of CSV data given query criteria.}
  spec.homepage      = "https://github.com/your_username/kenrick_csv"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.0"
end
