require "parslet"

class HCL::Parslet < Parslet::Parser
  rule(:document) {
    all_space >>
    ((key_value >> all_space) | comment_line).repeat >>
    all_space
  }
  root :document

  rule(:value) {
    array |
    object |
    string |
    key.as(:key) |
    float.as(:float) |
    integer.as(:integer) |
    boolean |
    heredoc.as(:heredoc)
  }

  rule(:object) {
    str("{") >> all_space >> array_comments >>
      ( ( key_value >> (all_space >> str(",").maybe).maybe ).repeat ).maybe.as(:object) >>
      str("}")
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

  rule(:float) {
    sign? >>
      (match["0-9"] >> match["0-9"].repeat).maybe >> str(".") >>
      (match["0-9"] >> match["0-9"].repeat) >> exponent.maybe
  }

  rule(:key) {
    string | (match["\\w_\\-"] >> match["\\w\\d_\\-.:"].repeat)
  }

  rule(:key_value) {
    space >> key.as(:key) >> space >>
      ((key >> space).repeat.maybe >> object | (str("=") >> space >> value)).as(:value)
  }

  rule (:sq_string) {
    str("'") >> match["^'\\n"].repeat.maybe.as(:string) >> str("'")
  }

  rule(:dq_string) {
    str('"') >> (
    match["^\"\\\\"] | escape | hil
    ).repeat.as(:string) >> str('"')
  }

  rule(:string) {
    sq_string | dq_string
  }

  rule(:hil) {
    str("${") >> value.maybe >> str("}")
  }

  rule(:heredoc)  {
    space >>
      backticks >>
      tag.capture(:tag) >> doc.as(:doc)
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

  rule(:hex) {
    match["0-9a-fA-F"]
  }

  rule(:escape) {
    str("\\") >> (match["bfnrt\"\\\\"] |
                  (str("u") >> hex.repeat(4,4)) |
                   (str("U") >> hex.repeat(8,8)))
  }

  rule(:boolean) { str("true").as(:true) | str("false").as(:false) }

  rule(:space) { match[" \t"].repeat }
  rule(:all_space) { match[" \t\r\n"].repeat }
  rule(:newline) { str("\r").maybe >> str("\n") | str("\r") >> str("\n").maybe }
  rule(:eof) { any.absent? }
  rule(:newline_or_eof) { newline | eof }

  rule(:comment_line) { comment >> newline_or_eof >> all_space }
  rule(:single_comment) { (str("#") | str("//")) >> match["^\n"].repeat }
  rule(:multiline_comment) { str("/*") >> (str("*/").absent? >> any).repeat >> str("*/") }
  rule(:comment) { single_comment | multiline_comment }

  # Finding comments in multiline arrays requires accepting a bunch of
  # possible newlines and stuff before the comment
  rule(:array_comments) { (all_space >> comment_line).repeat }

  rule(:array) {
    str("[") >> all_space >> array_comments >>
    ( array_comments >> # Match any comments on first line
      all_space >> value >> array_comments >>
      (
        # Separator followed by any comments
        all_space >> str(",") >> array_comments >>
        # Value followed by any comments
        all_space >> value >> array_comments
      ).repeat >>
      (all_space >> str(",")).maybe >> # possible trailing comma
      all_space >> array_comments # Grab any remaining comments just in case
    ).maybe.as(:array) >> str("]")
  }
end
