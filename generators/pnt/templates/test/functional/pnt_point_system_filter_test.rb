require File.dirname(__FILE__) + '/../test_helper'
require File.dirname(__FILE__) + '/../../vendor/plugins/pnt/test/functional/pnt_point_system_filter_test.rb'

class PntPointSystemFilterTest < ActionController::TestCase
  include PntPointSystemFilterTestModule
  
  def setup
    @controller = PointSystemFilterTestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  # You must write UnitTest!!
  def test_default
    assert true
  end
    
end