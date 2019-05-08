class HCL::Parser
  def initialize(src)
    @src = src
    @parslet = HCL::Parslet.new
  end

  def parse
    ast = begin
	    @parslet.parse(@src)
	  rescue Parslet::ParseFailed => error
	    puts error.parse_failure_cause.ascii_tree
	    raise
	  end

    HCL::Decoder.new.decode(ast)
  end
end
