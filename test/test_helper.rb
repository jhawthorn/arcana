$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "arcana"
require "minitest/autorun"

Minitest::Test.make_my_diffs_pretty!
