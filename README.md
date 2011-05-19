# Template Parser

Parse ASCII files by example

## Basic usage

First, create a template. In this example I'm parsing an ASCII purchase
order of some sort.

  template = TemplateParser.compile_template([
    "?<:>REPORT NUMBER: ?                                                                                                                 ",
    " INVENTORY NO:  #number                REF NUMBER:  #refer_number                  LOGICAL UNIT: #unit_number    ?                   ",
    "                    CATALOG CODE:    :cat_code   :sub_code                         VENDOR NO:    :vendor                             ",
    "                    TYPE CODE:       :lpr                FLAG: ?  BILL FLAG: <:bill_flag>#_    SHIPPING FROM: ?            SHIPPING TO: ?        ",
    "                    FROM-LOCATION:  :address_code                  TO LOCATION: :to_address_code                                     ",
    "                                    :address_name                               ?                                                    ",
    "                                    :address_1                                  ?                                                    ",
    "                                    :address_2                                  ?                                                    ",
    "                                    :address_city         :address_postal       ?                                                    ",
    "                    USER NAME: :user_name                                            SERIAL NUMBER: :serial                          "
    ].join("\n"))

Let's break down the template a little bit.

The first thing to note is that it's not hard to imagine what the date
we're parsing will actually look like. That's because the field
definitions go in the physical locations where the data should be, while
the rest of the report appears unchanged. While parsing a report, if a
single character is out of place, parsing will fail with a detailed
error message. I've found that by failing fast I've been able to find
the edge cases easily and get perfect parsing results on literally
gigabytes of generated reports.

There are a few different types of fields visible here as well. Some
start with #, indicating a numeric field. Most start with : and look
like symbols, indicating a text field. There are also some ?'s
indicating that something may appear there but we'll ignore it. Finally
there are some zero-width field names which look like <:name>:_ which
can appear where the field name would otherwise not fit. A variation of
that is where <:> can be used by itself as a 0-width delimiter to
prevent a field from being too long.

Side note: typically I would use [ruby here doc](http://blog.jayfields.com/2006/12/ruby-multiline-strings-here-doc-or.html)
string notation but here am concatinating an array of strings to help
demonstrate that whitespace is significant. That way I can just copy in
an example of the report I'm interested in and carve out my field
definitions directly.

An array of line matchers are returned from the compile_template method.

### Using the array of line matchers (template)

Does the given line have a match in any of the lines in the template?

  TemplateParser.match_template?(template, line)

Get the results of matching any line in the template to the given line

  TemplateParser.match_template(template, line, file_position_metadata) { |matcher, converted_data, raw_data| }

Process all given lines against the template in order

  TemplateParser.process_lines(template, lines, file_position_metadata)

Return true if process_lines would run successfully on the given lines
for the given template.

  TemplateParser.lines_match_template?(template, lines)

### Using individual line matchers

Does the given line match the given line matcher?

  TemplateParser.match_line?(line_matcher, line)

Process a given line against a given line matcher

  TemplateParser.process_line(line_matcher, line, file_position_metadata) { |matcher, converted_data, raw_data| }

