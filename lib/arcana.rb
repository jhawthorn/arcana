class Arcana
  EMPTY_ARRAY = [].freeze

  class Offset
    def initialize(str)
      @str = str
    end

    def exact?
      @str.match?(/\A[0-9]+\z/)
    end

    def position
      Integer(@str)
    end
  end

  class Pattern
    attr_reader :type, :flags, :value

    def initialize(type, value)
      @type, *@flags = type.split("/")
      @value = value
      @value = @value[1..] if @value.start_with?("=")
    end

    def match?(input)
      return if !input
      return if input.empty?
      flags = @flags.dup

      return if @type.include?("&") # fixme
      return if @type.include?("%") # fixme

      case @type
      when "string", "ustring"
        flags.delete("b") # force on binary files
        flags.delete("t") # force on text files 

        flags.delete("w") # FIXME: blanks
        flags.delete("W") # FIXME: blanks
        flags.delete("c") # FIXME: case insensitive
        flags.delete("C") # FIXME: case insensitive

        value = @value.dup.b
        value.gsub!("\\n", "\n")
        value.gsub!(/\\([0-9]+)/) { |match| Integer($1, 10).chr(Encoding::UTF_8).b }
        value.gsub!(/\\x([0-9a-fA-F]{2})/) { |match| Integer($1, 16).chr }
        value.gsub!(/\\(.)/, "\\1") # FIXME!!

        input.start_with?(value)
      when "byte"
        match_packed_integer?(input, "c", 1)
      when "ubyte"
        match_packed_integer?(input, "C", 1)
      when "short"
        match_packed_integer?(input, "s", 2)
      when "long"
        match_packed_integer?(input, "l", 4)
      when "quad"
        match_packed_integer?(input, "q", 8)
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
        return false # FIXME
      when "clear"
        return false # FIXME
      when "name"
        return false # FIXME
      when "use"
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
        regex = @value
        regex = regex.gsub(/\\(.)/, "\\1") # FIXME!!
        input[0,length].match?(regex)
      when "search"
        flags = @flags
        flags = ["1"] if flags.empty? # FIXME: WTF?
        search_input = input[0, @value.size + Integer(flags[0]) - 1]
        flags = flags[1..]

        flags.delete("b") # force on binary files
        flags.delete("t") # force on text files 

        flags.delete("c") # FIXME: case insensitive
        flags.delete("C") # FIXME: case insensitive

        input.include?(@value)
      else
        raise "Unsupported match type: #{@type}"
      end
    end

    private

    def match_packed_integer?(input, pack_str, length)
      input = input[0, length]
      return false unless input.length == length
      val = input.unpack(pack_str)[0]
      match_integer?(val)
    end

    def match_integer?(val)
      return false unless val
      return false unless @value.match?(/\A[0-9]+\z/) # FIXME
      val == Integer(@value)
    end
  end

  class Rule
    attr_reader :offset, :pattern, :message, :extras, :children, :parent

    def initialize(offset, pattern, message, parent)
      @offset = offset
      @pattern = pattern
      @message = message
      @extras = {}
      @parent = parent
      @children = []
    end

    def match(original_input)
      return EMPTY_ARRAY unless @offset.exact?

      input = original_input[@offset.position..]
      if @pattern.match?(input)
        child_matches = children.flat_map { |child| child.match(original_input) }
        if child_matches.any?
          child_matches
        else
          [self]
        end
      else
        EMPTY_ARRAY
      end
    end

    def mime_type
      extras["mime"] || (parent && parent.mime_type)
    end

    def full_message
      self_and_ancestors.map(&:message).compact.join
    end

    def self_and_ancestors
      if parent
        [*parent.self_and_ancestors, self]
      else
        [self]
      end
    end
  end

  class RuleSet
    def initialize(rules)
      @rules = rules
    end

    def match(string)
      @rules.flat_map do |rule|
        rule.match(string)
      end.map(&:mime_type)
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
          fields = line.chomp.split(/(?<!\\)\s+/, 4)
          offset, type, test, message = fields
          nesting = offset[/\A>*/].size

          stack = stack[0, nesting]

          offset = Offset.new offset[nesting..]
          pattern = Pattern.new(type, test)

          rule = Rule.new(offset, pattern, message, stack.last)
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
