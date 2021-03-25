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
    end

    def match?(input)
      case @type
      when "string"
        flags.delete("b") # force on binary files
        flags.delete("t") # force on text files 

        binding.irb if flags.any?
        input.start_with?(@value)
      when "long"
        input = input[0,4]
        input.unpack("l")[0] == Integer(@value)
      when "leshort"
        input = input[0,2]
        input.unpack("s<")[0] == Integer(@value)
      when "beshort"
        input = input[0,2]
        input.unpack("s>")[0] == Integer(@value)
      when "lelong"
        input = input[0,4]
        input.unpack("l<")[0] == Integer(@value)
      when "ubelong"
        input = input[0,4]
        input.unpack("L>")[0] == Integer(@value)
      when "belong"
        input = input[0,4]
        input.unpack("l>")[0] == Integer(@value)
      when "search"
        raise unless flags == ["1"]
        input.start_with?(@value)
      else
        raise "Unsupported match type: #{@type}"
      end
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
          next unless message
          next if nesting > 0
          next if type.include?("&")

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
  end

  DB_PATH = "../file/magic/Magdir"
  DB = Magdir.new(DB_PATH)
end
