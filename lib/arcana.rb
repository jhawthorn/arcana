class Arcana
  class Offset
    def initialize(str)
      @str = str
    end
  end

  class Pattern
    def initialize(type, value)
      @type, *@flags = type.split("/")
      @value = value
    end
  end

  class Rule
  end

  class File
    def initialize(path)
      @path = path
      @rules = parse
    end

    def parse
      rules = []

      ::File.foreach(@path) do |line|
        if line.start_with?("#")
          # comment
        elsif line.start_with?("!")
          # value
        elsif line.match?(/\A\s+\z/)
          # blank
        else
          fields = line.chomp.split(/(?<!\\)\s+/, 4)
          offset, type, test, message = fields
          nesting = offset[/\A>*/].size

          # FIXME: very WIP
          next unless message
          next if nesting > 0

          offset = Offset.new offset[nesting..]
          pattern = Pattern.new(type, test)

          rules << Rule.new(offset, pattern, message)
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

  p DB.open("ruby")
end
