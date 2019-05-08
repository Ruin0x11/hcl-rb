require "./lib/hcl/version"

Gem::Specification.new do |spec|
  spec.name          = "hcl"
  spec.version       = HCL::VERSION
  spec.authors       = ["Ruin0x11"]
  spec.email         = ["ipickering2@gmail.com"]

  spec.homepage      = "https://www.github.com/Ruin0x11/hcl-rb"
  spec.summary       = "A ruby parser for HCL (Hashicorp Configuration Language)."
  spec.license       = "MIT"
  if spec.respond_to?(:metadata)
    spec.metadata["source_code_uri"] = "https://www.github.com/Ruin0x11/hcl-rb"
  end

  all_files       = `git ls-files -z`.split("\x0")
  spec.files         = all_files.grep(%r{^(bin|lib)/})
  spec.executables   = all_files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency "parslet", "~> 1.8"
end
