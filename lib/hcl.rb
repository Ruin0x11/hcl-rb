require "hcl/version"
require "hcl/ast_visitor"
require "hcl/decoder"
require "hcl/generator"
require "hcl/parser"
require "hcl/parslet"

module HCL
  def self.load(source)
    HCL::Parser.new(source).parse
  end

  def self.load_file(path)
    HCL::Parser.new(File.read(path)).parse
  end
end
