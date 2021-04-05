# encoding: binary
#
require "test_helper"

class SimpleTest < Minitest::Test
  def setup
    @db = Arcana::DB
  end

  def test_can_detect_blank_gif
    data = "GIF89a\x01\x00\x01\x00\x80\x00\x00\xFF\xFF\xFF\x00\x00\x00!\xF9\x04\x00\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;".b
    rules = @db.open("images").rules
    mime_types = rules.match(data).map(&:mime_type).uniq.compact
    assert_equal ["image/gif"], mime_types
  end

  def test_can_detect_empty_gzip
    data = "\x1F\x8B\b\x00\xAE\x86\xE1[\x02\x03\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    rules = @db.open("compress").rules
    mime_types = rules.match(data).map(&:mime_type).uniq.compact
    assert_equal ["application/gzip"], mime_types
  end

  def test_can_detect_jpeg
    data = "\xFF\xD8\xFF\xDB\x00C\x00\x03\x02\x02\x02\x02\x02\x03\x02\x02\x02\x03\x03\x03\x03\x04\x06\x04\x04\x04\x04\x04\b\x06\x06\x05\x06\t\b\n\n\t\b\t\t\n\f\x0F\f\n\v\x0E\v\t\t\r\x11\r\x0E\x0F\x10\x10\x11\x10\n\f\x12\x13\x12\x10\x13\x0F\x10\x10\x10\xFF\xC9\x00\v\b\x00\x01\x00\x01\x01\x01\x11\x00\xFF\xCC\x00\x06\x00\x10\x10\x05\xFF\xDA\x00\b\x01\x01\x00\x00?\x00\xD2\xCF \xFF\xD9"
    rules = @db.open("jpeg").rules
    mime_types = rules.match(data).map(&:mime_type).uniq.compact
    assert_equal ["image/jpeg"], mime_types
  end

  def test_can_detect_elf
    data = "\x7FELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00\x01\x00\x00\x00\x19@\xCD\x80,\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x004\x00 \x00\x01\x00\x00\x00\x00\x00\x00\x00\x00@\xCD\x80\x00@\xCD\x80L\x00\x00\x00L\x00\x00\x00\x05\x00\x00\x00\x00\x10\x00\x00"
    rules = @db.open("elf").rules

    # FIXME: missing mime type
    assert_includes rules.match(data).map(&:full_message), "ELF 32-bit"
  end

  def test_can_detect_rtf
    data = "{\\rtf1}"
    rules = @db.open("rtf").rules
    mime_types = rules.match(data).map(&:mime_type).uniq.compact
    assert_equal ["text/rtf"], mime_types
  end

  def test_can_detect_pbm
    data = "P1 1 1 0"
    rules = @db.open("images").rules
    mime_types = rules.match(data).map(&:mime_type).uniq.compact
    assert_equal ["image/x-portable-bitmap"], mime_types
  end

  def test_can_detect_strict_xhtml
    data = '<html xmlns="http://www.w3.org/1999/xhtml"><head><title/></head><body/></html>'
    rules = @db.open("sgml").rules
    mime_types = rules.match(data).map(&:mime_type).uniq.compact
    assert_equal ["text/html"], mime_types
  end

  def test_can_match_simple_svg
    data = '<svg xmlns="http://www.w3.org/2000/svg"/>'
    rules = @db.open("sgml").rules
    mime_types = rules.match(data).map(&:mime_type).uniq.compact
    assert_equal ["image/svg+xml"], mime_types
  end

  def test_can_simple_mp3
    data = "\xFF\xE3\x18\xC4\x00\x00\x00\x03H\x00\x00\x00\x00LAME3.98.2\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    rules = @db.open("animation").rules
    mime_types = rules.match(data).map(&:mime_type).uniq.compact
    assert_equal ["audio/mpeg"], mime_types
  end
end
