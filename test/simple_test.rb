require "test_helper"

class SimpleTest < Minitest::Test
  def setup
    @db = Arcana::DB
  end

  def test_can_detect_blank_gif
    data = "GIF89a\x01\x00\x01\x00\x80\x00\x00\xFF\xFF\xFF\x00\x00\x00!\xF9\x04\x00\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;".b
    rules = @db.open("images").rules
    p rules.match(data)
  end
end
