# -*- coding: utf-8 -*-

require File.expand_path('../../test_helper', __FILE__)

class DecoderTest < Minitest::Test
  def assert_decodes(expected, src)
    ast = HCL::Parser.new.parse(src)
    assert_equal expected, decode(ast), "AST: '#{ast}'"
  end

  def decode(ast)
    HCL::Decoder.new.decode(ast)
  end

  def test_decodes_empty
    assert_decodes({}, "")
  end

  def test_decodes_comments
    assert_decodes({}, <<'END'
# hogehoge
# fuga hoge
END
)
  end

  def test_decodes_bool
    assert_decodes({"x" => true, "y" => false}, <<'END'
x = true
y = false
END
)
  end

  def test_decodes_int
    assert_decodes({"x" => 1, "y" => 0, "z" => -1}, <<'END'
x = 1
y = 0
z = -1
END
)
  end

  def test_decodes_float
    assert_decodes({"x" => 1.0, "y" => 0.5, "z" => -124.12, "w" => -0.524}, <<'END'
x = 1.0
y = .5
z = -124.12
w = -0.524
END
)
  end

  def test_decodes_empty_double_quoted_string
    assert_decodes({"x" => ""}, <<'END'
x = ""
END
)
  end

  def test_decodes_double_quoted_string
    assert_decodes({"x" => "hoge", "y" => "hoge \"fuga\" hoge", "z" => "??"}, <<'END'
x = "hoge"
y = "hoge \"fuga\" hoge"
z = "\u003F\U0000003F"
END
)
  end

  def test_decodes_double_quoted_string_escapes
    assert_decodes({"x" => "\b\f\n\r\t"}, <<'END'
x = "\b\f\n\r\t"
END
)
  end

  def test_decodes_halfwidth_katakana_string
    assert_decodes({"x" => "ｴｰﾃﾙ病"}, <<'END'
x = "ｴｰﾃﾙ病"
END
)
  end

  def test_decodes_identifiers
    assert_decodes({"x" => "hoge", "y" => "hoge.fuga", "z" => "_000.hoge::fuga-piyo"}, <<'END'
x = hoge
y = hoge.fuga
z = _000.hoge::fuga-piyo
END
)
  end

  def test_decodes_hil
    assert_decodes({"x" => "${hoge}", "y" => "${hoge {\"fuga\"} hoge}", "z" => "${name(hoge)}"}, <<'END'
x = "${hoge}"
y = "${hoge {\"fuga\"} hoge}"
z = "${name(hoge)}"
END
)
  end

  def test_decodes_heredocs
    assert_decodes({"hoge" => "Hello\nWorld\n"}, <<'END'
hoge = <<EOF
Hello
World
EOF
END
)

    assert_decodes({"fuga" => "\thoge\n\tfuga\n"}, <<'END'
fuga = <<FOO123
	hoge
	fuga
FOO123
END
)
  end

  def test_decodes_indented_heredoc
    assert_decodes({"piyo" => "Outer text\n\tIndented text\n"}, <<'END'
piyo = <<-EOF
			Outer text
				Indented text
			EOF
END
)
    assert_decodes({"hoge" => "Hello\n  World\n"}, <<'END'
hoge = <<-EOF
    Hello
      World
    EOF
END
)
  end

  def test_decodes_empty_single_quoted_string
    assert_decodes({"x" => ""}, <<'END'
x = ''
END
)
  end

  def test_decodes_single_quoted_string
    assert_decodes({"x" => "foo bar \"foo bar\""}, <<'END'
x = 'foo bar "foo bar"'
END
)
  end

  def test_decodes_list
    assert_decodes({"x" => [1, 2, 3],
                    "y" => [],
                    "z" => [ "", "" ],
                    "w" => [1, "string", "heredoc contents\n"]}, <<'END'
x = [1, 2, 3]
y = []
z = ["", "", ]
w = [1, "string", <<EOF
heredoc contents
EOF]
END
)
  end

  def test_decodes_list_of_maps
    assert_decodes({"foo" => [{"key" => "hoge"}, {"key" => "fuga", "key2" => "piyo"}]}, <<'END'
foo = [
  {key = "hoge"},
  {key = "fuga", key2 = "piyo"},
]
END
)
  end

  def test_decodes_leading_comment_in_list
    assert_decodes({"foo" => [1, 2, 3]}, <<'END'
foo = [
1,
# bar
2,
3,
],
END
)
  end

  def test_decodes_comment_in_list
    assert_decodes({"foo" => [1, 2, 3]}, <<'END'
foo = [
1,
2, # bar
3,
],
END
)
  end

  def test_decodes_empty_object_type
    assert_decodes({"foo" => {}}, <<'END'
foo = {}
END
)
  end

  def test_decodes_simple_object_type
    assert_decodes({"foo" => {"bar" => "hoge"}}, <<'END'
foo = {
    bar = "hoge"
}
END
)
  end

  def test_decodes_object_type_with_two_fields
    assert_decodes({"foo" => {"bar" => "hoge", "baz" => ["piyo"]}}, <<'END'
foo = {
    bar = "hoge"
    baz = ["piyo"]
}
END
)
  end

  def test_decodes_object_type_nested_empty_map
    assert_decodes({"foo" => {"bar" => {}}}, <<'END'
foo = {
    bar = {}
}
END
)
  end

  def test_decodes_object_type_nested_empty_map_and_value
    assert_decodes({"foo" => {"bar" => {}, "foo" => true}}, <<'END'
foo = {
    bar = {}
    foo = true
}
END
)
  end

  def test_decodes_object_keys
    assert_decodes({"foo" => {}},               "foo {}")
    assert_decodes({"foo" => {}},               "foo = {}")
    assert_decodes({"foo" => "bar"},            "foo = bar")
    assert_decodes({"foo" => 123},              "foo = 123")
    assert_decodes({"foo" => "${var.bar}"},     "foo = \"${var.bar}\"")
    assert_decodes({"foo" => {}},               "\"foo\" {}")
    assert_decodes({"foo" => {}},               "\"foo\" = {}")
    assert_decodes({"foo" => "${var.bar}"},     "\"foo\" = \"${var.bar}\"")
    assert_decodes({"foo" => {"bar" => {}}},        "foo bar {}")
    assert_decodes({"foo" => {"bar" => {}}},        "foo \"bar\" {}")
    assert_decodes({"foo" => {"bar" => {}}},        "\"foo\" bar {}")
    assert_decodes({"foo" => {"bar" => {"baz" => {}}}}, "foo bar baz {}")
  end

  def test_decodes_nested_keys
    assert_decodes({"foo" => {"bar" => {"baz" => {"hoge" => "piyo"}}}}, <<'END'
foo "bar" baz { hoge = "piyo" }
END
)
  end

  def test_decodes_multiple_same_nested_keys
    assert_decodes({"foo" => {"bar" =>
                          [{"hoge" => "piyo", "hogera" => "fugera"},
                           {"hoge" => "fuge"},
                           {"hoge" => "baz"},
                          ]}}, <<'END'
foo bar { hoge = "piyo", hogera = "fugera" }
foo bar { hoge = "fuge" }
foo bar { hoge = "baz" }
END
)
  end

  def test_decodes_multiple_nested_keys
    assert_decodes({"foo" =>
                    {
                      "bar" => {"baz" => { "hoge" => "piyo" }, "hoge" => "piyo"},
                      "hoge" => "piyo",
                      "hogera" => {"hoge" => "piyo"}
                    }}, <<'END'
foo "bar" baz { hoge = "piyo" }
foo "bar" { hoge = "piyo" }
foo { hoge = "piyo" }
foo hogera { hoge = "piyo" }
END
)
  end

  def test_decodes_nested_assignment_to_string_and_ident
    assert_decodes({"foo" => {"bar" => {"baz" => {"hoge" => "fuge", "hogera" => "fugera"}}}}, <<'END'
foo "bar" baz { "hoge" = fuge }
"foo" bar baz { hogera = "fugera" }
END
)
  end

  def test_decodes_nested_assignment_with_object
    assert_decodes({"foo" => [6, {"bar" => {"hoge" => "piyo"}}]}, <<'END'
foo = 6
foo "bar" { hoge = "piyo" }
END
)
  end

  def test_decodes_non_ident_keys
    assert_decodes({"本" => "foo"}, <<'END'
"本" = foo
END
)
  end

  def test_decodes_official
    skip ""
  end
end
