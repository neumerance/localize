require 'test_helper'

class VouchersControllerTest < ActionController::TestCase
  fixtures :vouchers, :users, :user_sessions

  test 'should get index' do
    get :index, params: params_with_session(:admin)
    assert_response :success
    assert_not_nil assigns(:vouchers)
  end

  test 'should get new' do
    get :new, params: params_with_session(:admin)
    assert_response :success
  end

  test 'should create voucher' do
    assert_difference('Voucher.count') do
      post :create, params: params_with_session(:admin, voucher: { code: Faker::Code.asin, amount: 10, active: true, comments: Faker::Lorem.words(10).join(' ') })
    end

    assert_redirected_to vouchers_path
  end

  test 'should get edit' do
    get :edit, params: params_with_session(:admin, id: vouchers(:one).to_param)
    assert_response :success
  end

  test 'should update voucher' do
    put :update, params: params_with_session(:admin, id: vouchers(:one).to_param, voucher: {})
    assert_redirected_to vouchers_path
  end

  test 'should destroy voucher' do
    assert_difference('Voucher.count', -1) do
      delete :destroy, params: params_with_session(:admin, id: vouchers(:one).to_param)
    end

    assert_redirected_to vouchers_path
  end
end
