require "parslet"

class HCL::Parslet < Parslet::Parser
  rule(:document) {
    all_space >>
    ((key_value >> all_space) | comment_line).repeat.as(:document) >>
    all_space
  }
  root :document

  rule(:value) {
    boolean.as(:boolean) |
    list |
    object |
    float.as(:float) |
    scientific.as(:float) |
    integer.as(:integer) |
    string |
    key.as(:key_string) |
    heredoc.as(:heredoc)
  }

  rule(:trailing_comma?) {
    (all_space >> str(",").maybe).maybe
  }

  rule (:dood) {
  }

  rule(:object) {
    str("{") >> list_comments >> all_space >>
      ( ( key_value >> list_comments >> all_space ).repeat ).maybe.as(:object) >>
      str("}") >> list_comments
  }

  rule(:sign) { str("-") }
  rule(:sign?) { sign.maybe }

  rule(:integer) {
    str("0") | sign? >>
      (match["1-9"] >> match["0-9"].repeat)
  }

  rule(:exponent) {
    match["eE"] >> match["+\\-"].maybe >> match["0-9"].repeat
  }

  rule(:scientific) {
    sign? >>
      (match["0-9"] >> match["0-9"].repeat) >> exponent
  }

  rule(:float) {
    sign? >>
      (match["0-9"] >> match["0-9"].repeat).maybe >> str(".") >>
      (match["0-9"] >> match["0-9"].repeat) >> exponent.maybe
  }

  rule(:key) {
    string | (match["\\w_\\-"] >> match["\\w\\d_\\-.:"].repeat)
  }

  rule(:key_value) {
    space >> key.as(:kv_key) >> space >>
      ((key.as(:key) >> space).repeat.as(:keys) >> object.as(:value) | (str("=") >> space >> value.as(:value))) >> trailing_comma?
  }

  rule (:sq_string) {
    str("'") >> match["^'\\n"].repeat.maybe.as(:string) >> str("'")
  }

  rule (:string_inner) {
    match["^\"\\\\"] | escape
  }

  rule(:dq_string) {
    str('"') >> (hil | (str("${").absent? >> string_inner)).repeat.as(:string) >> str('"')
  }

  rule(:string) {
    sq_string | dq_string
  }

  rule(:hil_inner) {
    brace | match["^\\\\}"] | escape
  }

  rule(:hil) {
    str("${") >> hil_inner.repeat.maybe >> str("}")
  }

  rule (:brace) {
    str("{") >> hil_inner.repeat.maybe >> str("}")
  }

  rule(:heredoc)  {
    space >>
      backticks.as(:backticks) >>
      tag.capture(:tag).as(:tag) >> doc.as(:doc)
  }

  rule(:hex) {
    match["0-9a-fA-F"]
  }

  rule(:escape) {
    str("\\") >> (match["bfnrt\"\\\\"] |
                  (str("u") >> hex.repeat(4,4)) |
                   (str("U") >> hex.repeat(8,8)))
  }

  # the tag that delimits the heredoc
  rule(:tag) { match['\\w\\d'].repeat(1) }
  # the doc itself, ends when tag is found at start of line
  rule(:doc) { gobble_eol >> doc_line }
  # a doc_line is either the stop tag followed by nothing
  # or just any kind of line.
  rule(:doc_line) {
    ((space >> end_tag).absent? >> gobble_eol).repeat >> space >> end_tag
  }
  rule(:end_tag) { dynamic { |s,c| str(c.captures[:tag]) } }
  # eats anything until an end of line is found
  rule(:gobble_eol) { (newline.absent? >> any).repeat >> newline }

  rule(:backticks) { str('<<') >> str("-").maybe }

  rule(:boolean) { str("true") | str("false") }

  rule(:space) { match[" \t"].repeat }
  rule(:all_space) { match[" \t\r\n"].repeat }
  rule(:newline) { str("\r").maybe >> str("\n") | str("\r") >> str("\n").maybe }
  rule(:eof) { any.absent? }
  rule(:newline_or_eof) { newline | eof }

  rule(:comment_line) { comment >> all_space }
  rule(:single_comment) { (str("#") | str("//")) >> match["^\n"].repeat >> newline_or_eof }
  rule(:multiline_comment) { str("/*") >> (str("*/").absent? >> any).repeat >> str("*/") }
  rule(:comment) { (single_comment | multiline_comment).as(:comment) }

  # Finding comments in multiline lists requires accepting a bunch of
  # possible newlines and stuff before the comment
  rule(:list_comments) { (all_space >> comment_line).repeat }

  rule(:list) {
    str("[") >> all_space >> list_comments >>
    ( list_comments >> # Match any comments on first line
     dood >>
      (all_space >> str(",")).maybe >> # possible trailing comma
      all_space >> list_comments # Grab any remaining comments just in case
    ).maybe.as(:list) >> str("]")
  }

  rule (:dood) {
      all_space >> (value >> list_comments).as(:value) >>
      (
        # Separator followed by any comments
        all_space >> str(",") >> (list_comments >>
        # Value followed by any comments
        all_space >> value).as(:value) >> list_comments >> all_space
      ).repeat
  }
end
