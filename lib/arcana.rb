class Arcana
  EMPTY_ARRAY = [].freeze

  class Cursor
    attr_reader :buf, :offset

    def initialize(buf)
      @buf = buf
      @base = @offset = 0
    end

    def eof?
      @offset >= @buf.size
    end

    def read(n)
      ret = peek(n)
      seek_relative(n)
      ret
    end

    def peek(n)
      @buf[@offset, n]
    end

    def mark_base
      @base += @offset
      @offset = 0
    end

    def seek_absolute(offset)
      if offset < 0
        @offset = @buf.size + offset
      else
        @offset = offset
      end
    end

    def seek_pos(offset)
      seek_absolute(@base + offset)
    end

    def seek_relative(offset)
      @offset += offset
    end

    def restore
      prev = @offset, @base
      yield
    ensure
      @offset, @base = prev
    end

    def inspect
      "#<#{self.class} offset=#{@offset}>"
    end
  end

  class Offset
    def initialize(str)
      @str = str
    end

    def exact?
      @str.match?(/\A(?:-?[0-9]+|0x[0-9a-fA-F]+)\z/)
    end

    def indirect?
      @str.start_with?("(")
    end

    def relative?
      @str.start_with?("&")
    end

    def seek(input)
      pos = position(input)
      return if pos.nil? # FIXME: raise?
      input.seek_absolute(pos)
    end

    def position(input)
      if exact?
        Integer(@str)
      elsif indirect?
        @str.match(/\A\(([0-9]+|0x[0-9a-fA-F]+)([.,])([bBcCeEfFgGhHiIlLmsSqQ])([+-](?:[0-9]+|0x[0-9a-fA-F]+))?\)\z/) || return
        add = $4 ? Integer($4) : 0
        value = read_indirect(input, offset: Integer($1), signed: ($2 == ","), type: $3)
        return unless value # fixme
        value + add
      else
        binding.irb
      end
    end

    def to_s
      @str
    end

    private

    def read_indirect(input, offset:, type:, signed:)
      input.seek_absolute(offset)
      return if input.eof? # FIXME

      case type
      when "b", "c", "B", "C"
        input.read(1).ord
      when "h", "s"
        input.read(2).unpack("s<")[0]
      when "H", "S"
        input.read(2).unpack("s>")[0]
      when "l"
        # also default?
        input.read(2).unpack("l<")[0]
      when "L"
        # also default?
        input.read(2).unpack("l>")[0]
      when "I"
        # https://stackoverflow.com/questions/5223025/why-do-mp3-files-use-synchsafe-integers
        bytes = input.read(4).bytes
        bytes[0] << 21 | bytes[1] << 14 | bytes[2] << 7 | bytes[3]
      else
        binding.irb
        raise "unsupported indirect type: #{type}"
      end
    end
  end

  class Pattern
    attr_reader :type, :flags, :value

    def initialize(type, value)
      type, *@flags = type.split("/")
      @type, *@type_ops = type.split(/(?=[&%+-])/)
      @value = value
    end

    def match?(input)
      return true if @value == "x"

      return if !input
      return if input.eof?
      flags = @flags.dup

      case @type
      when "string", "ustring"
        flags.delete("b") # force on binary files
        flags.delete("t") # force on text files 

        flags.delete("w") # FIXME: blanks
        flags.delete("W") # FIXME: blanks
        flags.delete("c") # FIXME: case insensitive
        flags.delete("C") # FIXME: case insensitive

        if @value.start_with?("!")
          test_string = parse_string(@value[1..])
          input.read(test_string.length) != test_string
        elsif @value.start_with?("=")
          test_string = parse_string(@value[1..])
          input.read(test_string.length) == test_string
        else
          test_string = parse_string(@value)
          input.read(test_string.length) == test_string
        end
      when "byte"
        match_packed_integer?(input, "c", 1)
      when "ubyte"
        match_packed_integer?(input, "C", 1)
      when "short"
        match_packed_integer?(input, "s", 2)
      when "ushort"
        match_packed_integer?(input, "S", 2)
      when "long"
        match_packed_integer?(input, "l", 4)
      when "ulong"
        match_packed_integer?(input, "L", 4)
      when "quad"
        match_packed_integer?(input, "q", 8)
      when "uquad"
        match_packed_integer?(input, "Q", 8)
      when "leshort"
        match_packed_integer?(input, "s<", 2)
      when "uleshort"
        match_packed_integer?(input, "S<", 2)
      when "beshort"
        match_packed_integer?(input, "s>", 2)
      when "ubeshort"
        match_packed_integer?(input, "S>", 2)
      when "lelong"
        match_packed_integer?(input, "l<", 4)
      when "ulelong"
        match_packed_integer?(input, "L<", 4)
      when "belong"
        match_packed_integer?(input, "l>", 4)
      when "ubelong"
        match_packed_integer?(input, "L>", 4)
      when "bequad"
        match_packed_integer?(input, "q>", 8)
      when "ubequad"
        match_packed_integer?(input, "Q>", 8)
      when "lequad"
        match_packed_integer?(input, "q<", 8)
      when "ulequad"
        match_packed_integer?(input, "Q<", 8)
      when "pstring"
        return false # FIXME
      when "guid"
        return false # FIXME
      when "der"
        return false # FIXME
      when "lestring16"
        return false # FIXME
      when "default"
        return true # FIXME
      when "clear"
        return true # FIXME
      when "name"
        return false
      when "use"
        return false
      when "offset"
        match_integer?(input.offset)
      when "indirect"
        return false # FIXME
      when "ledate"
        return false # FIXME
      when "bedate"
        return false # FIXME
      when "beldate"
        return false # FIXME
      when "beqdate"
        return false # FIXME
      when "lefloat"
        return false # FIXME
      when "regex"
        if length = flags[0]
          if length.end_with?("l")
            # lines
            length = 8196
          elsif length.match?(/\A[0-9]+\z/)
            length = Integer(length)
          else
            return false # FIXME
          end
        else
          length = 8196
        end
        regex = parse_string(@value)
        # FIXME: seek input to result location
        input.peek(length).match?(regex)
      when "search"
        flags = @flags

        flags.delete("b") # force on binary files
        flags.delete("t") # force on text files 

        flags.delete("c") # FIXME: case insensitive
        flags.delete("C") # FIXME: case insensitive

        flags = ["1"] if flags.empty? # FIXME: WTF?
        search_input = input.peek(@value.size + Integer(flags[0]) - 1)
        flags = flags[1..]

        value = parse_string(@value)

        # FIXME: seek input to result location
        search_input.include?(value)
      else
        raise "Unsupported match type: #{@type}"
      end
    end

    private

    def parse_string(value)
      value = value.dup.b
      value.gsub!(/\\([0-7]{1,3})/) { |match| Integer($1, 8).chr rescue binding.irb }
      value.gsub!(/\\x([0-9a-fA-F]{2})/) { |match| Integer($1, 16).chr }
      value.gsub!(/\\(.)/) do
        case $1
        when "n" then "\n"
        when "t" then "\t"
        when "f" then "\f"
        when "r" then "\r"
        else $1
        end
      end
      value
    end

    def match_packed_integer?(input, pack_str, length)
      input = input.read(length)
      return false unless input && input.length == length
      val = input.unpack(pack_str)[0]
      match_integer?(val, bitwidth: length*8)
    end

    def match_integer?(val, bitwidth: 64, match_value: @value)
      return true if match_value == "x"
      return false unless val

      @type_ops.each do |op|
        op.match(/\A([&%])?(0x[0-9a-fA-F]+|-?[0-9]+)[lL]?\z/) || raise
        operand = Integer($2)
        case $1
        when "&"
          val &= operand
        when "%"
          val %= operand
        end
      end

      if match_value.match(/\A([=><!&^])? ?(0x[0-9a-fA-F]+|-?[0-9]+)[lL]?\z/)
        operator = $1
        comparison = Integer($2)

        if $2.start_with?("0x") && !@type.start_with?("u")
          # is it signed?
          if comparison.anybits?(1 << (bitwidth - 1))
            comparison = -(((1 << bitwidth) - 1) ^ comparison) - 1
          end
        end

        if @type_ops.any?
          comparison &= (1 << bitwidth) - 1
        end

        case operator
        when "=", nil
          val == comparison
        when "<"
          val < comparison
        when ">"
          val > comparison
        when "!"
          val != comparison
        when "&"
          (val & comparison) == comparison
        when "^"
          (val & comparison) == 0
        end
      else
        binding.irb
        false # FIXME
      end
    end
  end

  class Result
    attr_reader :ruleset

    def initialize(ruleset, stack=[])
      @ruleset = ruleset
      @stack = stack
    end

    def add(rule)
      Result.new(ruleset, @stack + [rule])
    end

    def mime_type
      @stack.map(&:mime_type).compact.last
    end

    def full_message
      @stack.map(&:message).compact.join(" ")
    end

    def last_rule
      @stack.last
    end

    def inspect
      "#<Arcana::Result mime=#{mime_type.inspect} message=#{full_message.inspect} stack=#{@stack.inspect}>"
    end
  end

  class Rule
    attr_reader :offset, :pattern, :message, :extras, :children

    def initialize(offset, pattern, message)
      @offset = offset
      @pattern = pattern
      @message = message
      @extras = {}
      @children = []
    end

    def match(input, match)
      return EMPTY_ARRAY if @offset.relative?
      #return EMPTY_ARRAY unless @offset.exact?
      ruleset = match.ruleset

      input = Cursor.new(input) unless Cursor === input
      @offset.seek(input)

      if pattern.type == "use"
        return EMPTY_ARRAY if pattern.value.start_with?("\\^") # FIXME: endianness swap
        use = ruleset.names.fetch(pattern.value)
        input.restore do
          input.mark_base # FIXME: no idea if this works
          return use.match(input, match)
        end
        #return use.visit_children(input, match)
      elsif pattern.type == "indirect"
        # FIXME: do this better
        original_input = input.buf
        return match.ruleset.match(original_input[input.offset..], match)
      end

      if @pattern.match?(input)
        match = match.add(self)
        child_matches = visit_children(input, match)
        if child_matches.any?
          child_matches
        else
          match
        end
      else
        EMPTY_ARRAY
      end
    end

    def visit_children(input, match)
      children.flat_map do |child|
        input.restore do
          child.match(input, match)
        end
      end
    end

    def mime_type
      @extras["mime"]
    end

    def inspect
      "<#{self.class} #{@offset} #{@pattern.inspect} #{@message}>"
    end
  end

  class RuleSet
    def initialize(rules)
      @rules = rules
    end

    def match(string, result=Result.new(self))
      @rules.flat_map do |rule|
        rule.match(string, result)
      end
    end

    def names
      return @names if defined?(@names)
      @names = {}
      @rules.each do |rule|
        next unless rule.pattern.type == "name"
        @names[rule.pattern.value] = rule
      end
      @names
    end

    def inspect
      "#<#{self.class} #{@rules.size} rules>"
    end
  end

  class File
    def initialize(path)
      @path = path
      @rules = parse
    end

    def raw_rules
      @rules
    end

    def rules
      RuleSet.new(@rules)
    end

    def parse
      rules = []
      stack = []

      ::File.foreach(@path) do |line|
        if line.start_with?("#")
          # comment
        elsif line.match?(/\A\s+\z/)
          # blank
        elsif line.start_with?("!")
          if line =~ /\A!:([a-z]+)\s+(.*)\n\z/
            raise if stack.empty?
            stack.last.extras[$1] = $2
          else
            raise "couldn't parse #{line}"
          end
        else
          fields = line.chomp.split(/(?<![\\<>])\s+/, 4)
          offset, type, test, message = fields
          nesting = offset[/\A>*/].size

          stack = stack[0, nesting]

          offset = Offset.new offset[nesting..]
          pattern = Pattern.new(type, test)

          rule = Rule.new(offset, pattern, message)
          if stack.empty?
            rules << rule
          else
            stack.last.children << rule
          end
          stack << rule
        end
      end
      rules
    end
  end

  class Magdir
    def initialize(dir)
      @dir = dir
    end

    def open(path)
      Arcana::File.new(::File.join(@dir, path))
    end

    def files
      Dir.children(@dir).map do |path|
        open(path)
      end
    end

    def rules
      RuleSet.new(files.flat_map(&:raw_rules))
    end
  end

  DB_PATH = "../file/magic/Magdir"
  DB = Magdir.new(DB_PATH)
end
