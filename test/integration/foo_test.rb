require 'test_helper'

class FooTest < ActionController::IntegrationTest
  test "home page exists" do
    visit '/martview'
  end
end
