require File.dirname(__FILE__) + '/../../test_helper'

# filterでのポイント配布テストはcontrollerを使ったテストのためfunctional以下に格納されている。 

module PntPointSystemTestModule
  
  class << self
    def included(base)
      base.class_eval do
        fixtures :base_users
        fixtures :pnt_filters
        fixtures :pnt_filter_masters
        fixtures :pnt_masters
        fixtures :pnt_points
        fixtures :pnt_histories
      end
    end
  end
  
  define_method('test: pointregister で通常のポイントを配布処理をできる') do
 
   assert_difference "PntPoint.find_by_base_user_id(1).point", 100 do
     PntPointSystem.pointregister(1, 1, 100, "ポイントテスト")
   end

   pnt_point = PntPoint.find_base_user_point(1, 1)
   assert_not_nil(pnt_point)
   
   history = PntHistory.find(:first, :conditions => ['message = ? ', 'ポイントテスト'])
   assert_not_nil history
   assert_equal(history.pnt_point_id, pnt_point.id)
   assert_equal(history.difference, 100)
   assert_equal(history.amount, 200) 
  end

  define_method('test: pointregister で通常のポイントを減算処理をできる') do

    assert_difference "PntPoint.find_by_base_user_id(1).point", -100 do
      PntPointSystem.pointregister(1, 1, -100, "ポイントマイナステスト")
    end

    history = PntHistory.find(:first, :conditions => ['message = ? ', 'ポイントマイナステスト'])
    assert_not_nil history
    assert_equal(history.difference, -100)
    assert_equal(history.amount, 0) 
  end
  
end