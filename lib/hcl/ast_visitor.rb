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

    raise "not hash" unless Hash === ast

    type = @@types.find { |type| ast.key? type }
    raise "no type" unless type

    method_name = "visit_#{type}"
    send(method_name, ast)
  end

  def visit_document(ast)
    root = {}
    doc = ast[:document]
    if Array === doc
      doc.map { |i| visit(i) }.reject(&:nil?).reduce(&:merge)
    else
      doc
    end || {}
  end

  def conv_key(key)
    if Hash === key
      if key.key? :string
        key[:string].to_s
      elsif Hash === key[:key]
        p key[:key]
        key[:key][:string].to_s
      else
        key[:key].to_s
      end
    else
      key.to_s
    end
  end

  def visit_kv_key(ast)
    key = conv_key(ast[:kv_key])
    value = visit(ast[:value])

    extra_keys = ast[:keys]
    if extra_keys.nil? || extra_keys == []
      {key => value}
    else
      extra_keys.unshift(key)
      extra_keys.reverse.inject({}) do |h, k|
        { conv_key(k) => h }
      end
    end
  end

  def undump(str)
    hex = /[0-9a-fA-F]/
    esctable = {
      '\b' => "\b",
      '\f' => "\f",
      '\n' => "\n",
      '\r' => "\r",
      '\t' => "\t",
    }
    e = str.encoding
    s = if str[0] == '"' && str[-1] == '"'
        str[1..-2]
      else
        str.dup
      end
    s.gsub!(/\\"/, '"')
    s.gsub!(/\\\\/, '\\')
    s.gsub!(/\\[bfnrt]/) {|m| esctable[m]}
    s.gsub!(/\\u#{hex}{4}/) {|m| m[2..-1].hex.chr(e)}
    s.gsub!(/\\U#{hex}{8}/) {|m| m[2..-1].hex.chr(e)}
    s
  end

  def visit_string(ast)
    string = ast[:string]
    if string == []
      ""
    else
      undump(string.to_s)
    end
  end

  def visit_key_string(ast)
    ast[:key_string]
  end

  def visit_object(ast)
  end

  def visit_comment(ast)
  end

  def visit_integer(ast)
    ast[:integer].to_i
  end

  def visit_boolean(ast)
    case ast[:boolean]
    when "true" then
      true
    when "false"
      false
    else raise "unknown boolean #{ast}"
    end
  end

  def visit_float(ast)
    ast[:float].to_f
  end

  def visit_heredoc(ast)
    doc = ast[:heredoc]
    tag = doc[:tag]
    content = doc[:doc].to_s.gsub(/#{tag}$/, "")[1..-1]

    case doc[:backticks].to_s
    when "<<" then
      content
    when "<<-" then
      first = StringIO.open(content, &:readline)
      indent = /^\s+/.match(first).to_s

      deindent = ""
      content.each_line do |l|
        n = l.delete_prefix indent
        raise "invalid indent" if n == l
        deindent << n
      end

      deindent
    else raise "unknown backticks #{backticks}"
    end
  end

  def visit_list(ast)
    return [] if ast[:list].nil?

    list = if Hash === ast[:list]
             [ast[:list]]
           else
             ast[:list]
           end

    list.map do |a|
      value = a[:value]
      value = if Array === value
                it = value.reject { |i| i.key? :comment }
                raise "extra list value" unless it.size == 1
                it.first
              else
                value
              end
      visit(value)
    end.reject(&:nil?)
  end

  def visit_object(ast)
    if ast[:object] == ""
      {}
    else
      ast[:object].map { |a| visit(a) }.reject(&:nil?).reduce(&:merge)
    end
  end
end
