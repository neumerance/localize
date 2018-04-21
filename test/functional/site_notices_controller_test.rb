require File.dirname(__FILE__) + '/../test_helper'

class SiteNoticesControllerTest < ActionController::TestCase
  "
    def test_should_get_index
      get :index
      assert_response :success
      assert_not_nil assigns(:site_notices)
    end

    def test_should_get_new
      get :new
      assert_response :success
    end

    def test_should_create_site_notice
      assert_difference('SiteNotice.count') do
        post :create, :site_notice => { }
      end

      assert_redirected_to site_notice_path(assigns(:site_notice))
    end

    def test_should_show_site_notice
      get :show, :id => site_notices(:one).id
      assert_response :success
    end

    def test_should_get_edit
      get :edit, :id => site_notices(:one).id
      assert_response :success
    end

    def test_should_update_site_notice
      put :update, :id => site_notices(:one).id, :site_notice => { }
      assert_redirected_to site_notice_path(assigns(:site_notice))
    end

    def test_should_destroy_site_notice
      assert_difference('SiteNotice.count', -1) do
        delete :destroy, :id => site_notices(:one).id
      end

      assert_redirected_to site_notices_path
    end
    "
end
