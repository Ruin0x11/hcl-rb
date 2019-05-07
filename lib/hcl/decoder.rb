class HCL::Decoder

  def initialize
  end

  def decode(ast)
    HCL::ASTVisitor.new.visit(ast)
  end
end
