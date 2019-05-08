module HCL
  def self.escape_key(key)
    str = key.to_s
    pos = str =~ /[^a-zA-Z0-9_\-]/

    return str if pos.nil?

    str.dump
  end
end

class Object
  def hcl_object?
    self.kind_of?(Hash)
  end
  def hcl_list?
    self.kind_of?(Array) && self.first.hcl_object?
  end
end

class Hash
  def to_hcl(indent = 0)
    return "" if self.empty?
    hcl = ""
    spaces = " " * indent

    self.each do |k, v|
      next if v.hcl_object?
      next if v.hcl_list? and v.size > 0 and v.first.hcl_object?

      hcl << spaces
      hcl << HCL.escape_key(k) << " = "
      hcl << v.to_hcl(indent + 4)
      hcl << "\n"
    end

    self.each do |k, v|
      if v.hcl_object?
	key = HCL.escape_key(k)
	hcl << spaces
	hcl << key << " {\n"
	hcl << v.to_hcl(indent + 4)
	hcl << spaces << "}\n"
      end
      if v.hcl_list? and v.size > 0 and v.first.hcl_object?
	key = HCL.escape_key(k)
	hcl << spaces
	hcl << key << " = ["
	v.each do |i|
	  if i.hcl_object?
	    hcl << "\n" << spaces << "{\n"
	  else
	    hcl << spaces
	  end
	  hcl << i.to_hcl(indent + 4)
	  if i.hcl_object?
	    hcl << spaces << "},\n"
	  end
	end
	hcl << spaces << "]\n"
      end
    end

    hcl
  end
end
class Array
  def to_hcl(indent = 0)
    "[" + self.map {|v| v.to_hcl(indent) }.join(", ") + "]"
  end
end
class TrueClass
  def to_hcl(indent = 0); "true"; end
end
class FalseClass
  def to_hcl(indent = 0); "false"; end
end
class String
  def to_hcl(indent = 0); self.inspect; end
end
class Numeric
  def to_hcl(indent = 0); self.to_s; end
end
class Symbol
  def to_hcl(indent = 0); HCL.escape_key(self.to_s); end
end
class DateTime
  def to_hcl(indent = 0)
    self.to_time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end
end
