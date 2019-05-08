class HCL::Decoder < HCL::ASTVisitor
  def initialize
  end

  def decode(ast)
    visit(ast)
  end

  def visit_document(ast)
    doc = ast[:document]
    if Array === doc
      visit({object: doc})
    else
      doc
    end || {}
  end

  def conv_key(key)
    if Hash === key
      if key.key? :string
	key[:string]
      elsif Hash === key[:key]
	key[:key][:string]
      else
	key[:key]
      end
    else
      key
    end.to_s
  end

  def visit_kv_key(ast)
    key = conv_key(ast[:kv_key])
    value = visit(ast[:value])

    extra_keys = ast[:keys]
    if extra_keys.nil? || extra_keys == []
      { key => value }
    else
      rest = extra_keys.reverse.inject(value) do |h, k|
	{ conv_key(k) => h }
      end
      { key => rest }
    end
  end

  def newline?(b)
    b == "\n".ord || b == "\r".ord
  end

  SIMPLE_ESCAPES = [
    ["a", "\a"],
    ["b", "\b"],
    ["f", "\f"],
    ["n", "\n"],
    ["r", "\r"],
    ["t", "\t"],
    ["v", "\v"],
    ["\\", "\\"],
    ["'", "'"],
    ["\"", "\""]
  ].map { |a, b| [a.ord, b] }.to_h

  def undump(str)
    chunks = nil
    chunk_start = 0
    braces = 0
    dollar = false
    hil = false
    bytes = str.bytes

    io = StringIO.new(str)
    b = io.getbyte

    until b.nil?
      if braces == 0 and dollar and b == "{".ord
	braces += 1
	hil = true
      elsif braces > 0 and b == "{".ord
	braces += 1
      end

      if braces > 0 and b == "}".ord
	braces -= 1
      end

      dollar = false
      if braces == 0 and b == "$".ord
	dollar = true
      end

      if b == "\\".ord
	chunks = [] if chunks.nil?

	if chunk_start != io.pos-1
	  chunks << str[chunk_start..io.pos-2]
	end

	s = nil

	b = io.getbyte

	escape = SIMPLE_ESCAPES[b]

	if escape != nil
	  b = io.getbyte
	  s = escape
	elsif newline? b
	  raise "string literal not terminated" if braces == 0
	  b = io.getbyte while newline? b
	  s = "\n"
	elsif b == "x".ord
	  c1 = nil
	  c2 = nil

	  b = io.getbyte || 0

	  c1 = b.chr.hex
	  raise "invalid hexadecimal escape sequence" if c1.zero?

	  b = io.getbyte || 0

	  c2 = b.chr.hex
	  raise "invalid hexadecimal escape sequence" if c2.zero?

	  b = io.getbyte
	  s = (c1*16 + c2).to_s(16)
	elsif b == "u".ord || b == "U".ord
	  size = if b == "U".ord then 8 else 4 end

	  b = io.getbyte # Skip "u".

	  codepoint = 0
	  hexdigits = 0
	  while hexdigits < size
	    hex = b && b.chr.hex
	    raise "UTF-8 escape sequence contained invalid character:(#{b.chr})" unless hex

	    hexdigits += 1
	    codepoint = codepoint * 16 + hex

	    raise "UTF-8 escape sequence too large" if codepoint > 0x10FFFF

	    b = io.getbyte
	  end

	  s = codepoint.chr(Encoding::UTF_8)
	else
	  cb = b && b.chr.to_i

	  raise "invalid escape sequence" if cb.nil?

	  b = io.getbyte

	  if b != nil
	    c2 = b.chr.to_i

	    if b == "0".ord || c2 != 0
	      cb = 10 * cb + c2
	      b = io.getbyte

	      if b != nil
		c3 = b.chr.to_i

		if b == "0".ord || c3 != 0
		  cb = 10 * cb + c3

		  raise "invalid decimal escape sequence" if cb > 255

		  b = io.getbyte
		end
	      end
	    end
	  end

	  s = cb.chr
	end

	chunks << s if s != nil

	chunk_start = if b.nil? then io.pos else io.pos - 1 end
      elsif b.nil? || (newline? b && braces == 0)
	raise "unfinished string"
      else
	b = io.getbyte
      end
    end

    raise "expected terminating brace" if b.nil? and braces != 0

    if chunks != nil
      # Put last chunk into buffer.
      if chunk_start != io.pos
	chunks << str[chunk_start..io.pos-1]
      end

      chunks.join
    else
      # There were no escape sequences.
      str
    end
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
    ast[:key_string].to_s
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
      # We need to unindent each line based on the indentation level of the marker
      lines = content.split("\n")
      indent = lines.last

      indented = true
      lines.each do |line|
	if indent.size > line.size
	  indented = false
	  break
	end

	prefix_found = line.delete_prefix(indent) != line

	unless prefix_found
	  indented = false
	  break
	end
      end

      # If all lines are not at least as indented as the terminating mark, return the
      # heredoc as is, but trim the leading space from the marker on the final line.
      unless indented
	return content.sub(/\s+\Z/, "") + "\n"
      end

      unindented_lines = []
      lines.each do |line|
	unindented_lines << line.delete_prefix(indent)
      end
      unindented_lines.join("\n")
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

  def recurse_objects(a, b, keys)
    a_child = a.dup
    b_child = b.dup

    keys.each do |key|
      a_child = a_child[key]
      b_child = b_child[key]
    end

    return a_child, b_child
  end

  def hash_or_array(obj)
    Hash === obj or Array === obj
  end

  def common_nested_keys(a, b)
    a_child = a
    b_child = b

    keys = []
    finished = false

    until finished
      break if Array === a_child or Array === b_child
      break if a_child.nil? or b_child.nil?
      break if a_child.length > 1 or b_child.length > 1

      a_child.each do |k, v|
	finished = true if b_child[k].nil?
	finished = true if (not hash_or_array(a_child[k]) or not hash_or_array(b_child[k]))
	break if finished

	keys << k
	a_child = a_child[k]
	b_child = b_child[k]
	break
      end
    end

    return keys, a_child, b_child
  end

  def objects_share_keys?(a, b, keys)
    b.each_key do |k|
      return true if a.key? k
    end

    false
  end

  def set_object_nested(this, value, keys)
    raise "no keys" unless keys.size > 0

    if keys.size == 1
      this[keys.last] = value
      return
    end

    this_parent = this[keys.first]

    keys.drop(1).each do |key|
      this_parent = this_parent[key]
    end

    this_parent[keys.last] = value
  end

  def expand_objects(this, other, keys)
    this_child, other_child = recurse_objects(this, other, keys)

    set_object_nested(this, [this_child, other_child], keys)
  end

  def merge_object_lists(this, other, keys)
    this_child, other_child = recurse_objects(this, other, keys)

    if Hash === this_child && Array === other_child
      object = this_child
      list = other_child
    elsif Array === this_child && Hash === other_child
      object = other_child
      list = this_child
    else
      raise "not both lists" unless Array === this_child && Array == other_child
    end

    if list.nil?
      this_child.each_value do |v|
	other_child << v
      end

      set_object_nested(this, other_child, keys)
    else
      list << object
      set_object_nested(this, list, keys)
    end
  end

  def merge_objects(this, other)
    raise "merge_objects was called on the same object" if this == other
    raise "merge_objects was called with non-objects" unless Hash === this && Hash === other

    other.each do |k, v|
      tmp = this[k]
      if tmp != nil
	if Hash === tmp and Hash === v
	  merge_objects(tmp, v)
	else
	  this[k] = v
	end
      else
	this[k] = v
      end
    end
  end

  def visit_object(ast)
    object = ast[:object]
    return {} if object == ""

    pairs = ast[:object].map { |a| visit(a) }.reject(&:nil?)

    pairs.inject({}) do |result, object|
      first_key = object.sort.first[0]
      existing = result[first_key]
      value = object[first_key]
      expand = false

      if existing != nil
	if Array === existing
	  existing << value
	else
	  if Hash === existing
	    if not Hash === existing
	      expand = true
	    else
	      keys, a, b = common_nested_keys(existing, value)
	      if Array === a or Array === b
		merge_object_lists(existing, value, keys)
	      elsif objects_share_keys?(a, b, keys)
		if keys.size == 0
		  expand = true
		else
		  expand_objects(existing, value, keys)
		end
	      else
		merge_objects(existing, value)
		result[first_key] = existing
	      end
	    end
	  else
	    expand = true
	  end

	  if expand
	    result[first_key] = [existing, value]
	  end
	end
      else
	result[first_key] = value
      end

      result
    end
  end
end
