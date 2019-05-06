# -*- coding: utf-8 -*-

require File.expand_path('../../test_helper', __FILE__)

class ParsletTest < Minitest::Test
  def t(i)
    refute_nil HCL::Parser.new.parse(i)
  end

  def f(i)
    assert_raises Parslet::ParseFailed do
      HCL::Parser.new.parse(i)
    end
  end

  def test_parslet
    t("")

    t("a=1")
    t("a = 1")
    t("a = \"dood\"")
    t("a {b = 1}")
    t("a = {b = 1}")

    t("root {\na = 1\n}")
    t("root {\na = 1, b = 2\n}")

    t(<<'END'
# hogehoge
// fuga hoge
END
)

    t(<<'END'
x = true
y = false
END
)

    t(<<'END'
x = 1
y = 0
z = -1
END
)

    t(<<'END'
x = 1.0
y = .5
z = -124.12
w = -0.524
END
)

    t(<<'END'
x = ""
END
)
    f(<<'END'
x = "hoge \"
END
)

    t(<<'END'
x = "hoge \"fuga\" hoge"
END
)

    t(<<'END'
x = "hoge"
y = "hoge \"fuga\" hoge"
z = "\u003F\U0000003F"
END
)

    t(<<'END'
x = "ｴｰﾃﾙ病"
END
)

    t(<<'END'
x = hoge
y = hoge.fuga
z = _000.hoge::fuga-piyo
END
)

    t(<<'END'
x = "${hoge}"
y = "${hoge {\"fuga\"} hoge}"
z = "${name(hoge)}"
END
)

    t(<<'END'
piyo = <<-EOF
			Outer text
				Indented text
			EOF
END
)

    t(<<'END'
hoge = <<EOF
Hello
World
EOF
fuga = <<FOO123
	hoge
	fuga
FOO123
piyo = <<-EOF
			Outer text
				Indented text
			EOF
END
)

    t(<<'END'
hoge = <<-EOF
    Hello
      World
    EOF
END
)

    t(<<'END'
x = ''
END
)

    t(<<'END'
x = 'foo bar "foo bar"'
END
)

    t(<<'END'
x = [1, 2, 3]
y = []
z = ["", "", ]
w = [1, "string", <<EOF
heredoc contents
EOF]
END
)

    t(<<'END'
foo = [
  {key = "hoge"},
  {key = "fuga", key2 = "piyo"},
]
END
)

    t(<<'END'
foo = [
1,
# bar
2,
3,
]
END
)

    t(<<'END'
foo = {}
END
)

    t(<<'END'
foo = {
    bar = "hoge"
    baz = ["piyo"]
}
END
)

    t(<<'END'
foo = {
    bar = {}
}
END
)

    t(<<'END'
foo = {
    bar = {}
    foo = true
}
END
)

    t(<<'END'
foo {}
END
)

    t(<<'END'
foo = {}
END
)

    t(<<'END'
foo = bar
END
)

    t(<<'END'
foo = 123
END
)

    t(<<'END'
foo = 123
END
)

    t(<<'END'
"foo" {}
END
)

    t(<<'END'
"foo" = "${var.bar}"
END
)

    t(<<'END'
foo bar {}
END
)

    t(<<'END'
foo "bar" {}
END
)

    t(<<'END'
"foo" bar {}
END
)

    t(<<'END'
foo bar baz {}
END
)

    t(<<'END'
foo "bar" baz { "hoge" = fuge }
"foo" bar baz { hogera = "fugera" }
END
)

    t(<<'END'
foo = 6
foo "bar" { hoge = "piyo" }
END
)

    t("# Hello\n# World\n")
    t("# Hello\r\n# Windows")

    t("x = 1 # hogehoge")

    t(<<'END'
/* fugahoge */
/*
 * hoge
 */


/*
 * hoge

fuga
 */
END
)

    f("a b c = 1")
  end

  def test_official
    files = {
      "assign_colon.hcl" =>
      {line: 2,
       column: 7,
       end_column: 7,
       msg: "found invalid token when parsing object keys near ':'"},
      "comment.hcl" => nil,
      "comment_crlf.hcl" => nil,
      "comment_lastline.hcl" => nil,
      "comment_single.hcl" => nil,
      "empty.hcl" => nil,
      "list_comma.hcl" => nil,
      "multiple.hcl" => nil,
      "object_list_comma.hcl" => nil,
      "structure.hcl" => nil,
      "structure_basic.hcl" => nil,
      "structure_empty.hcl" => nil,
      "complex.hcl" => nil,
      "complex_crlf.hcl" => nil,
      "types.hcl" => nil,
      "array_comment.hcl" => nil,
      "array_comment_2.hcl" =>
      {line: 4,
       column: 5,
       end_column: 47,
       msg: "error parsing list, expected comma or list end near '\"${path.module}/scripts/install-haproxy.sh\"'"},
      "missing_braces.hcl" =>
      {line: 3,
       column: 22,
       end_column: 22,
       msg: "found invalid token when parsing object keys near '$'"},
      "unterminated_object.hcl" =>
      {line: 3,
       column: 1,
       end_column: 1,
       msg: "expected end of object list near <eof>"},
      "unterminated_object_2.hcl" =>
      {line: 7,
       column: 1,
       end_column: 1,
       msg: "expected end of object list near <eof>"},
      "key_without_value.hcl" =>
      {line: 2,
       column: 1,
       end_column: 1,
       msg: "end of file reached near <eof>"},
      "object_key_without_value.hcl" =>
      {line: 3,
       column: 1,
       end_column: 1,
       msg: "found invalid token when parsing object keys near '}'"},
      "object_key_assign_without_value.hcl" =>
      {line: 3,
       column: 1,
       end_column: 1,
       msg: "Unknown token near '}'"},
      "object_key_assign_without_value2.hcl" =>
      {line: 4,
       column: 1,
       end_column: 1,
       msg: "Unknown token near '}'"},
      "object_key_assign_without_value3.hcl" =>
      {line: 3,
       column: 7,
       end_column: 7,
       msg: "expected to find at least one object key near '='"},
      "git_crypt.hcl" =>
      {line: 1,
       column: 1,
       end_column: 1,
       msg: "found invalid token when parsing object keys near '\\0'"}}

    files.each do |file, error|
      src = File.read(File.expand_path("test/fixtures/parser/#{file}"))

      if error.nil?
        t(src)
      else
        f(src)
      end
    end
  end
end
