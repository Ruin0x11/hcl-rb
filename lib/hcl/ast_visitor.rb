class HCL::ASTVisitor
  @@types = [
    :document,
    :kv_key,
    :string,
    :key_string,
    :object,
    :comment,
    :integer,
    :boolean,
    :float,
    :heredoc,
    :list,
    :object
  ]

  def visit(ast)
    return nil unless ast

    raise "AST object must be Hash" unless Hash === ast

    type = @@types.find { |type| ast.key? type }
    raise "Couldn't determine AST object type" unless type

    method_name = "visit_#{type}"
    send(method_name, ast)
  end
end
