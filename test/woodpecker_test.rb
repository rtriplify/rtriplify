require File.dirname(__FILE__) + '/test_helper.rb'
class WoodpeckerTest < Test::Unit::TestCase
  load_schema
  def test_woodpecker
    assert_kind_of Woodpecker, Woodpecker.new
  end
end
