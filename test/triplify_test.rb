require 'test_helper'

class YaffleTest < Test::Unit::TestCase load_schema
  class Hickwall < ActiveRecord::Base
  end
  class Wickwall < ActiveRecord::Base
  end
  def test_schema_has_loaded_correctly assert_equal [], Hickwall.all assert_equal [], Wickwall.all
  end
end

