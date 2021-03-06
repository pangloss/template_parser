module TemplateParser
  class ProcessingError < StandardError
    attr_reader :matcher, :line, :pos, :meta

    def initialize(matcher, line, pos, meta, message)
      @matcher, @line, @pos, @meta = matcher, line, pos, meta
      super(message)
    end
  end

  class ProcessingErrors < StandardError
    attr_reader :errors

    def initialize(message, errors)
      @errors = errors
      super(message + "\n\n" + errors.map { |e| e.message }.compact.join("\n-----------------------------------------------------------\n"))
    end
  end

  module Parser
    # Create an array of line matchers based on a template.
    def compile_template(template)
      template_lines = template.to_enum(:each_line).map { |line| line.chomp }
      template_lines.map do |line|
        compile_template_line(line)
      end
    end

    # Does the given line match the given line matcher?
    def match_line?(matchers, line)
      matchers.first[:regex] =~ line
    end

    # Does the given line have a match in any of the lines in the template?
    def match_template?(template, line)
      template.detect { |matcher| match_line?(matcher, line) }
    end

    # Return true if process_lines would run successfully on the given
    # lines for the given template.
    def lines_match_template?(template, lines)
      template.zip(lines).all? do |matchers, line|
        match_line?(matchers, line)
      end
    end

    # Get the results of matching any line in the template to the given line
    def match_template(template, line, meta = {})
      matcher = match_template? template, line
      if matcher
        if block_given?
          process_line(matcher, line, meta) { |*x| yield *x }
        else
          process_line(matcher, line, meta)
        end
      else
        errors = template.map do |matcher|
          begin
            process_line(matcher, line, meta) { |*x| }
          rescue ProcessingError => e
            e
          end
        end
        raise ProcessingErrors.new("At least one of the following #{ template.length } template lines should match the given line", errors)
      end
    end

    # Process all given lines against the template in order
    def process_lines(line_matchers, lines, meta = {})
      record = {}
      line_matchers.zip(lines) do |matchers, line|
        process_line(matchers, line, meta) do |matcher, data, raw|
          record[matcher[:symbol]] = data if data != ''
        end
      end
      record
    end

    def formatters(template)
      template.map { |matcher| matcher.first[:formatter] }
    end

    def format_any_line(template, data)
      formatter = formatters(template).detect do |formatter|
        formatter[:lengths].all? do |name, length|
          data[name] and data[name].to_s.length <= length
        end
      end
      if formatter
        formatter[:format] % formatter[:keys].map { |key| data[key] }
      else
        raise 'No formatter found'
      end
    end

    def format_template(template, data)
      template.map do |matcher|
        formatter = matcher.first[:formatter]
        formatter[:format] % formatter[:keys].map { |key| data[key] }
      end.join "\n"
    end

    def process_any_line(template, line, meta = {})
      record = {}
      match_template(template, line) do |matcher, data, raw|
        record[matcher[:symbol]] = data if data != ''
      end
      record
    end

    # Process a given line against a given line matcher
    def process_line(matchers, line, meta = {})
      pos = 0
      unless block_given?
        record = {}
        process_line(matchers, line, meta) do |m, d, lp|
          record[m[:symbol]] = d
        end
        return record
      end
      matchers.each do |matcher|
        line_part = line[pos, matcher[:length]]
        processing_error!('Unexpected EOL', matcher, line, pos, meta) unless line_part
        #processing_error!('Unexpected EOL', matcher, line, pos, meta) if line_part.length < matcher[:length]
        case matcher[:type]
        when :string
          if matcher[:string] != line_part
            processing_error!("Mismatch: #{ line_part.inspect } should be #{ matcher[:string].inspect }", matcher, line, pos, meta)
          end
          yield matcher, line_part, line_part if matcher[:symbol]
        when :data
          yield matcher, line_part.strip, line_part
        when :int
          data = line_part.strip
          if data == ''
            yield matcher, nil, line_part
          else
            begin
              yield matcher, Integer(data.sub(/^0*(\d)/, '\1')), line_part
            rescue => e
              processing_error!(e.message, matcher, line, pos, meta)
            end
          end
        end
        pos += matcher[:length]
      end
    end

    private

    def compile_template_line(line)
      parts = line.split(/([#:]\w+\s*\]?|\?\s*\]?|<[#:]\w*>)/)
      next_symbol = nil
      next_type = nil
      matchers = parts.map do |part|
        len = part.length
        if len > 0
          if part =~ /^<[#:]\w*>$/
            next_symbol = part[2..-2]
            if next_symbol.length > 0
              next_symbol = next_symbol.to_sym
              next_type = part[1, 1] == '#' ? :int : :data
            else
              # <:> used as a 0-width delimiter
              next_symbol = nil
            end
            nil
          else
            part = part[0..-2] if part[-1, 1] == ']'
            matcher = case part[0, 1]
              when ':'
                { :type => :data, :symbol => part.strip[1..-1].to_sym, :length => len, :template => line }
              when '#'
                { :type => :int, :symbol => part.strip[1..-1].to_sym, :length => len, :template => line }
              when '?'
                { :type => :ignore, :length => len, :template => line }
              else
                { :type => :string, :string => part, :length => len, :template => line }
              end
            if next_symbol
              matcher[:symbol] = next_symbol
              matcher[:type] = next_type if matcher[:type] == :ignore
              next_symbol = nil
            end
            matcher
          end
        end
      end.compact
      compile_regex(matchers)
      compile_formatter(matchers)
      matchers
    end

    def compile_regex(matchers)
      str = matchers.map do |matcher|
        case matcher[:type]
        when :string
          "(?:#{Regexp.escape matcher[:string]}|#{Regexp.escape(matcher[:string].rstrip)}$)"
        when :int
          "(?:[ 0-9]{#{matcher[:length]}}|[ 0-9]{,#{matcher[:length]}}$)"
        when :data, :ignore
          "(?:.{#{matcher[:length]}}|.{,#{matcher[:length]}}$)"
        end
      end.join('')
      matchers.first[:regex] = Regexp.new("\\A#{ str }", Regexp::MULTILINE)
    end

    def compile_formatter(matchers)
      keys = []
      lengths = {}
      str = matchers.map do |matcher|
        if matcher[:symbol]
          keys << matcher[:symbol]
          lengths[matcher[:symbol]] = matcher[:length]
        end
        case matcher[:type]
        when :data
          "%-#{matcher[:length]}s"
        when :int
          "%#{matcher[:length]}s"
        when :ignore
          " " * matcher[:length]
        when :string
          matcher[:string]
        end
      end.join('')
      matchers.first[:formatter] = { :format => str, :keys => keys, :lengths => lengths }
    end

    def processing_error!(message, matcher, line, pos, meta)
      message = <<-MESSAGE
#{ message }:
  #{ matcher[:template].inspect.gsub(/<[:#]\w*>/, '') }
  #{ line.inspect }
   #{ ' ' * pos }^#{ '^' * (matcher[:length] > 0 ? matcher[:length] - 1 : 0) }
  file: #{ meta[:file] } @ #{ meta[:line_num] }
      MESSAGE
      message += "\n\n#{ meta[:lines] }" if meta[:lines]
      raise ProcessingError.new(matcher, line, pos, meta, message)
    end
  end

  extend Parser

  class Base
    include Parser
  end
end
