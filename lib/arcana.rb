class Arcana
  class Offset
    def initialize(str)
      @str = str
    end

    def zero?
      @str == "0"
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
      return if input.empty?
      flags = @flags.dup

      case @type
      when "string", "ustring"
        flags.delete("b") # force on binary files
        flags.delete("t") # force on text files 

        flags.delete("w") # FIXME: blanks
        flags.delete("W") # FIXME: blanks
        flags.delete("c") # FIXME: case insensitive
        flags.delete("C") # FIXME: case insensitive

        #binding.irb if flags.any?

        input.start_with?(@value)
      when "byte"
        input = input[0]
        match_integer? input.unpack("c")[0]
      when "ubyte"
        input = input[0]
        match_integer? input.unpack("C")[0]
      when "ubyte"
        input = input[0]
        match_integer? input.unpack("C")[0]
      when "short"
        input = input[0,2]
        match_integer? input.unpack("s")[0]
      when "short"
        input = input[0,2]
        match_integer? input.unpack("s")[0]
      when "long"
        input = input[0,4]
        match_integer? input.unpack("l")[0]
      when "quad"
        input = input[0,8]
        match_integer? input.unpack("q")[0]
      when "uleshort"
        input = input[0,2]
        match_integer? input.unpack("S<")[0]
      when "leshort"
        input = input[0,2]
        match_integer? input.unpack("s<")[0]
      when "beshort"
        input = input[0,2]
        match_integer? input.unpack("s>")[0]
      when "ubeshort"
        input = input[0,2]
        match_integer? input.unpack("S>")[0]
      when "lelong"
        input = input[0,4]
        match_integer? input.unpack("l<")[0]
      when "ulelong"
        input = input[0,4]
        match_integer? input.unpack("L<")[0]
      when "ubelong"
        input = input[0,4]
        match_integer? input.unpack("L>")[0]
      when "belong"
        input = input[0,4]
        match_integer? input.unpack("l>")[0]
      when "bequad"
        input = input[0,8]
        match_integer? input.unpack("q>")[0]
      when "lequad"
        input = input[0,8]
        match_integer? input.unpack("q<")[0]
      when "ulequad"
        input = input[0,8]
        match_integer? input.unpack("Q<")[0]
      when "ubequad"
        input = input[0,8]
        match_integer? input.unpack("Q>")[0]
      when "pstring"
        return false # FIXME
      when "guid"
        return false # FIXME
      when "der"
        return false # FIXME
      when "lestring16"
        return false # FIXME
      when "regex"
        if length = flags[0]
          if length.end_with?("l")
            # lines
            length = 8196
          else
            length = Integer(length)
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

    def match_integer?(val)
      return false unless val
      return false unless @value.match?(/\A[0-9]+\z/) # FIXME
      val == Integer(@value)
    end
  end

  class Rule
    attr_reader :offset, :pattern, :message, :extras

    def initialize(offset, pattern, message)
      @offset = offset
      @pattern = pattern
      @message = message
      @extras = {}
    end

    def match?(input)
      # FIXME: WIP
      return false unless @offset.zero?

      @pattern.match?(input)
    end
  end

  class RuleSet
    def initialize(rules)
      @rules = rules
    end

    def match(string)
      @rules.select do |rule|
        rule.match?(string)
      end
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
      last_rule = nil

      ::File.foreach(@path) do |line|
        if line.start_with?("#")
          # comment
        elsif line.match?(/\A\s+\z/)
          # blank
        elsif line.start_with?("!")
          if line =~ /\A!:([a-z]+)\s+(.*)\n\z/
            next unless last_rule
            last_rule.extras[$1] = $2
          else
            raise "couldn't parse #{line}"
          end
        else
          last_rule = nil
          fields = line.chomp.split(/(?<!\\)\s+/, 4)
          offset, type, test, message = fields
          nesting = offset[/\A>*/].size

          # FIXME: very WIP
          #next unless message
          next if nesting > 0
          next if type.include?("&")
          next if type.start_with?("name")
          next if type.start_with?("use")

          offset = Offset.new offset[nesting..]
          pattern = Pattern.new(type, test)

          last_rule = Rule.new(offset, pattern, message)
          rules << last_rule
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
