class HCL::Parser
  def initialize
    @parslet = HCL::Parslet.new
  end

  def parse(it, opt = nil)
    begin
      if opt
        return @parslet.send(opt).parse(it, reporter: Parslet::ErrorReporter::Tree.new)
      else
        return @parslet.parse(it, reporter: Parslet::ErrorReporter::Tree.new)
      end
    rescue Parslet::ParseFailed => error
      puts error.parse_failure_cause.ascii_tree
      raise
    end
  end
end
