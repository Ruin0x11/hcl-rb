# -*- coding: utf-8 -*-

require File.expand_path('../../test_helper', __FILE__)

class ParsletTest < Minitest::Test
  def assert_fails_parse(i)
    assert_raises Parslet::ParseFailed do
      HCL::Parser.new.parse(i)
    end
  end

  def parse(s, it = nil)
    HCL::Parser.new.parse(s, it)
  end

  def assert_parses(expected, src)
    assert_equal expected, parse(src), "Source: '#{src}'"
  end

  def test_parses_empty
    assert_parses({document: []}, "")
  end

  def test_parses_comments_single
    assert_parses({document: [{comment: "# hogehoge\n"}, {comment: "// fuga hoge\n"}]}, <<'END'
# hogehoge
// fuga hoge
END
)

    assert_parses({document:
                   [{key: "x", value: {integer: "1"}}, {comment: "# hogehoge"}]},
                  "x = 1 # hogehoge")
  end

  def test_parses_key_value
    assert_parses({document: [{key: "a", value: {integer: "1"}}]}, "a=1")
    assert_parses({document: [{key: "a", value: {integer: "1"}}]}, "a = 1")
    assert_parses({document: [{key: "a", value: {string: "dood"}}]}, "a = \"dood\"")
  end

  def test_parses_bool
    assert_parses({document: [{key: "x", value: {boolean: "true"}}, {key: "y", value: {boolean: "false"}}]}, <<'END'
x = true
y = false
END
)
  end

  def test_parses_integer
    assert_parses({document:
                   [{key: "x", value: {integer: "1"}},
                    {key: "y", value: {integer: "0"}},
                    {key: "z", value: {integer: "-1"}},
                   ]}, <<'END'
x = 1
y = 0
z = -1
END
)
  end

  def test_parses_float
    assert_parses({document:
                   [{key: "x", value: {float: "1.0"}},
                    {key: "y", value: {float: ".5"}},
                    {key: "z", value: {float: "-124.12"}},
                    {key: "w", value: {float: "-0.524"}},
                   ]}, <<'END'
x = 1.0
y = .5
z = -124.12
w = -0.524
END
)
  end

  def test_parses_string_dq
    assert_parses({document:
                   [{key: "x", value: {string: []}}
                   ]}, <<'END'
x = ""
END
)

    assert_fails_parse(<<'END'
x = "hoge \"
END
)


    assert_parses({document:
                   [{key: "x", value: {string: "hoge"}},
                    {key: "y", value: {string: "hoge \\\"fuga\\\" hoge"}},
                    {key: "z", value: {string: "\\u003F\\U0000003F"}},
                    ]}, <<'END'
x = "hoge"
y = "hoge \"fuga\" hoge"
z = "\u003F\U0000003F"
END
)


    assert_parses({document:
                   [{key: "x", value: {string: "ｴｰﾃﾙ病"}}
                   ]}, <<'END'
x = "ｴｰﾃﾙ病"
END
)
  end

  def test_parses_keys
    assert_parses({document:
                   [{key: "x", value: {key: "hoge"}},
                    {key: "y", value: {key: "hoge.fuga"}},
                    {key: "z", value: {key: "_000.hoge::fuga-piyo"}},
                   ]}, <<'END'
x = hoge
y = hoge.fuga
z = _000.hoge::fuga-piyo
END
)
  end

  def test_parses_hil
    assert_parses({document:
                   [
                     {key: "x", value: {string: "${hoge}"}},
                     {key: "y", value: {string: "${hoge {\\\"fuga\\\"} hoge}"}},
                     {key: "z", value: {string: "${name(hoge)}"}},
                   ]}, <<'END'
x = "${hoge}"
y = "${hoge {\"fuga\"} hoge}"
z = "${name(hoge)}"
END
)

    assert_fails_parse(<<'END'
x = "${hoge"
END
)
  end

  def test_parses_heredocs
    assert_parses({document:
                   [{key: "piyo", value:
                     {heredoc: {backticks: "<<-",
                                tag: "EOF",
                                doc: "\n                        Outer text\n                                Indented text\n                        EOF"}}}
                   ]}, <<'END'
piyo = <<-EOF
                        Outer text
                                Indented text
                        EOF
END
)

    assert_parses({document:
                   [{key: "hoge", value: {heredoc: {backticks: "<<", tag: "EOF", doc: "\nHello\nWorld\nEOF"}}},
                    {key: "fuga", value: {heredoc: {backticks: "<<", tag: "FOO123", doc: "\n        hoge\n        fuga\nFOO123"}}},
                    {key: "piyo", value: {heredoc: {backticks: "<<-", tag: "EOF", doc: "\n                        Outer text\n                                Indented text\n                        EOF"}}},
                   ]}, <<'END'
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


    assert_parses({document:
                   [{key: "hoge", value: {heredoc: {backticks: "<<-", tag: "EOF", doc: "\n    Hello\n      World\n    EOF"}}},
                   ]}, <<'END'
hoge = <<-EOF
    Hello
      World
    EOF
END
)
  end

  def test_parses_string_sq
    assert_parses({document:
                   [{key: "x", value: {string: ""}}
                   ]}, <<'END'
x = ''
END
)


    assert_parses({document:
                   [{key: "x", value: {string: "foo bar \"foo bar\""}}
                   ]}, <<'END'
x = 'foo bar "foo bar"'
END
)
  end

  def test_parses_arrays
    assert_parses({document:
                   [{key: "x", value: {array: [{value: {integer: "1"}}, {value: {integer: "2"}}, {value: {integer: "3"}}]}},
                    {key: "y", value: {array: nil}},
                    {key: "z", value: {array: [{value: {string: []}}, {value: {string: []}}]}},
                    {key: "w", value: {array: [{value: {integer: "1"}},
                                               {value: {string: "string"}},
                                               {value: {heredoc: {backticks: "<<",
                                                          tag: "EOF",
                                                          doc: "\nheredoc contents\nEOF"}}}]}},
                   ]}, <<'END'
x = [1, 2, 3]
y = []
z = ["", "", ]
w = [1, "string", <<EOF
heredoc contents
EOF]
END
)
  end

  def test_parses_array_of_objects
    assert_parses({document:
                   [{key: "foo", value:
                     {array: [
                       {value: {object: [{key: "key", value: {string: "hoge"}}]}},
                       {value: {object: [{key: "key", value: {string: "fuga"}}, {key: "key2", value: {string: "piyo"}}]}},
                     ]}}
                   ]}, <<'END'
foo = [
  {key = "hoge"},
  {key = "fuga", key2 = "piyo"},
]
END
)
  end

  def test_parses_array_with_comments
    assert_parses({document:
                   [{key: "foo", value:
                     [{comment: "# foo\n"},
                      {array: [
                        {value: {integer: "1"}}, {value: [{comment: "# bar\n"}, {integer: "2"}]}, {value: {integer: "3"}}
                      ]},
                     ]},
                    {comment: "# baz\n"}
                   ]}, <<'END'
foo = [ # foo
1,
# bar
2,
3,
] # baz
END
                 )
  end

  def test_parses_objects
    assert_parses({document: [{key: "a", keys: [],  value: {object: [{key: "b", value: {integer: "1"}}]}}]}, "a {b = 1}")
    assert_parses({document: [{key: "a",  value: {object: [{key: "b", value: {integer: "1"}}]}}]}, "a = {b = 1}")

    assert_parses({document: [{key: "root", keys: [], value: {object: [{key: "a", value: {integer: "1"}}]}}]}, "root {\na = 1\n}")
    assert_parses({document: [{key: "root", keys: [], value: {object: [{key: "a", value: {integer: "1"}}, {key: "b", value: {integer: "2"}}]}}]}, "root {\na = 1, b = 2\n}")

    assert_parses({document:
                   [{key: "foo", value: {object: ""}}
                   ]}, <<'END'
foo = {}
END
)

    assert_parses({document:
                   [{key: "foo", value:
                     {object: [
                       {key: "bar", value: {string: "hoge"}},
                       {key: "baz", value: {array: {value: {string: "piyo"}}}}]}
                    }]}, <<'END'
foo = {
    bar = "hoge"
    baz = ["piyo"]
}
END
)

    assert_parses({document:
                   [{key: "foo", value: [
                       {comment: "# comment\n"},
                       {comment: "# comment\n"},
                       {object: [{key: "bar", value: {string: "hoge"}},
                                 {comment: "# comment\n"},
                                 {key: "baz", value: {array: {value: {string: "piyo"}}}},
                                 {comment: "# comment\n"}]},
                       {comment: "# comment\n"}]}
                   ]}, <<'END'
foo = { # comment
# comment
    bar = "hoge" # comment
    baz = ["piyo"] # comment
} # comment
END
)

    assert_parses({document:
                   [{key: "foo", value:
                                 {object: [
                                   {key: "bar", value: {object: ""}}]}
                                }]}, <<'END'
foo = {
    bar = {}
}
END
)

    assert_parses({document:
                   [{key: "foo", value:
                      {object: [
                        {key: "bar", value: {object: ""}},
                        {key: "foo", value: {boolean: "true"}}]
                      }}]}, <<'END'
foo = {
    bar = {}
    foo = true
}
END
)
  end

  def test_parses_nested_keys
    assert_parses({document:
                   [{key: "foo", keys: [], value: {object: ""}}
                   ]}, <<'END'
foo {}
END
)

    assert_parses({document:
                   [{key: "foo", value: {object: ""}}
                   ]}, <<'END'
foo = {}
END
)

    assert_parses({document:
                   [{key: "foo", value: {key: "bar"}}
                   ]}, <<'END'
foo = bar
END
)


    assert_parses({document:
                   [{key: "foo", value: {integer: "123"}}
                   ]}, <<'END'
foo = 123
END
)


    assert_parses({document:
                   [{key: {string: "foo"}, keys: [],  value: {object: ""}}
                   ]}, <<'END'
"foo" {}
END
)

    assert_parses({document:
                   [{key: {string: "foo"}, value: {string: "${var.bar}"}}
                   ]}, <<'END'
"foo" = "${var.bar}"
END
)


    assert_parses({document:
                   [{key: "foo", keys: [{key: "bar"}], value: {object: ""}}
                   ]}, <<'END'
foo bar {}
END
)

    assert_parses({document:
                   [{key: "foo", keys: [{key: {string: "bar"}}], value: {object: ""}}
                   ]}, <<'END'
foo "bar" {}
END
)

    assert_parses({document:
                   [{key: {string: "foo"}, keys: [{key: "bar"}], value: {object: ""}}
                   ]}, <<'END'
"foo" bar {}
END
)

    assert_parses({document:
                   [{key: "foo", keys: [{key: "bar"}, {key: "baz"}], value: {object: ""}}
                   ]}, <<'END'
foo bar baz {}
END
)

    assert_parses({document:
                   [{key: "foo", keys: [{key: {string: "bar"}}, {key: "baz"}], value:
                     {object: [
                       {key: {string: "hoge"}, value: {key: "fuge"}}]}},
                    {key: {string: "foo"}, keys: [{key: "bar"}, {key: "baz"}], value:
                     {object: [
                       {key: "hogera", value: {string: "fugera"}}]}}
                   ]}, <<'END'
foo "bar" baz { "hoge" = fuge }
"foo" bar baz { hogera = "fugera" }
END
)


    assert_parses({document:
                   [{key: "foo", value: {integer: "6"}},
                    {key: "foo", keys: [{key: {string: "bar"}}], value:
                     {object: [{key: "hoge", value: {string: "piyo"}}]}}
                   ]}, <<'END'
foo = 6
foo "bar" { hoge = "piyo" }
END
)

    assert_fails_parse "a b c = 1"
  end

  def test_parses_comment_newlines
    assert_parses({document:
                   [{:comment=>"# Hello\n"}, {:comment=>"# World\n"}]},
                  "# Hello\n# World\n")

    assert_parses({document:
                   [{:comment=>"# Hello\r\n"}, {:comment=>"# Windows"}]},
                  "# Hello\r\n# Windows")
  end

  def test_parses_comments_multiline
    assert_parses({document:
                   [{comment: "/* fugahoge */"},
                    {comment: "/*\n * hoge\n */"},
                    {comment: "/*\n * hoge\n\nfuga\n */"}
                   ]}, <<'END'
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
        parse(src)
      else
        assert_fails_parse src
      end
    end
  end
end
