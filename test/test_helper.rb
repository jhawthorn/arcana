$ cat test/test_helper.rb
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "arcana"

require "minitest/autorun"
