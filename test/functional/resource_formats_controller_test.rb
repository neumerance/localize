require File.dirname(__FILE__) + '/../test_helper'

class ResourceFormatsControllerTest < ActionController::TestCase
  "
    def test_should_get_index
      get :index
      assert_response :success
      assert_not_nil assigns(:resource_formats)
    end

    def test_should_get_new
      get :new
      assert_response :success
    end

    def test_should_create_resource_format
      assert_difference('ResourceFormat.count') do
        post :create, :resource_format => { }
      end

      assert_redirected_to resource_format_path(assigns(:resource_format))
    end

    def test_should_show_resource_format
      get :show, :id => resource_formats(:one).id
      assert_response :success
    end

    def test_should_get_edit
      get :edit, :id => resource_formats(:one).id
      assert_response :success
    end

    def test_should_update_resource_format
      put :update, :id => resource_formats(:one).id, :resource_format => { }
      assert_redirected_to resource_format_path(assigns(:resource_format))
    end

    def test_should_destroy_resource_format
      assert_difference('ResourceFormat.count', -1) do
        delete :destroy, :id => resource_formats(:one).id
      end

      assert_redirected_to resource_formats_path
    end
  "
end
