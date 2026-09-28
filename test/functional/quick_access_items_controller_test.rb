# frozen_string_literal: true

require_relative '../test_helper'

class QuickAccessItemsControllerTest < Redmine::ControllerTest
  fixtures :quick_access_items, :users, :issues, :projects, :members, :member_roles, :roles,
           :trackers, :issue_statuses, :enumerations, :enabled_modules,
           :wikis, :wiki_pages, :wiki_contents, :versions

  setup do
    @request.session[:user_id] = 2
  end

  test 'login is required for read actions' do
    @request.session[:user_id] = nil

    get :index
    assert_redirected_to signin_url(back_url: quick_access_items_url)

    get :preview
    assert_redirected_to signin_url(back_url: quick_access_items_url)

    get :preview, xhr: true
    assert_response :unauthorized
  end

  test 'index lists all visible items' do
    get :index

    assert_response :success
    assert_select 'table.quick-access tbody tr', count: 3
    assert_select 'table.quick-access tbody tr:first-child' do
      assert_select 'td.quick-access-project a[href=?]', '/projects/ecookbook'
      assert_select 'td.quick-access-type', text: 'Issue'
      assert_select 'td.quick-access-name a[href=?]', '/issues/2'
      assert_select 'td.buttons a', text: 'Remove from quick access'
    end
    assert_select 'td.quick-access-name a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation'
    assert_select 'td.quick-access-name a[href=?]', '/versions/1'
  end

  test 'preview renders the latest items and a link to the full list' do
    get :preview

    assert_response :success
    assert_select 'ul.quick-access-preview-items' do
      assert_select 'li.quick-access-preview-item a', count: 3
      assert_select 'li.quick-access-preview-item:first-child a[href=?]', '/issues/2'
      assert_select 'li:last-child.quick-access-preview-more a[href=?]', '/quick_access'
    end
  end

  test 'preview renders the empty state' do
    QuickAccessItem.delete_all
    get :preview

    assert_response :success
    assert_select 'p.nodata', text: I18n.t(:label_no_quick_access_items)
  end

  test 'index renders the empty state' do
    QuickAccessItem.delete_all
    get :index

    assert_response :success
    assert_select 'p.nodata', text: I18n.t(:label_no_data)
  end

  test 'create quick_access_items a visible issue with a javascript response and is idempotent' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all

    assert_difference 'QuickAccessItem.count', 1 do
      post :create, params: {target_type: 'Issue', target_id: 1}, xhr: true
    end
    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 1}, xhr: true
    end
    assert_response :success
    assert_equal 1, QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).count
    assert_includes response.body, 'quick-access-toggle-issue-1'
    assert_includes response.body, "quick-access-preview:invalidate"
  end

  test 'create redirects HTML back to a safe referring page' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    @request.env['HTTP_REFERER'] = issue_url(1)

    post :create, params: {target_type: 'Issue', target_id: 1}

    assert_redirected_to issue_url(1)
    assert_equal 1, QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).count
  end

  test 'create accepts each allowlisted target type' do
    targets = [Issue.find(1), WikiPage.find(1), Version.find(1)]
    targets.each do |target|
      type = target.class.base_class.name
      QuickAccessItem.where(user_id: 2, target_type: type, target_id: target.id).delete_all

      assert_difference 'QuickAccessItem.count', 1 do
        post :create, params: {target_type: type, target_id: target.id}, xhr: true
      end
      assert_response :success
    end
  end

  test 'create rejects unsupported types' do
    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Project', target_id: 1}, xhr: true
    end
    assert_response :not_found
  end

  test 'create rejects a missing supported target' do
    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 999_999}, xhr: true
    end
    assert_response :not_found
  end

  test 'create rejects an invisible target' do
    Issue.any_instance.stubs(:visible?).with(User.find(2)).returns(false)

    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 1}, xhr: true
    end
    assert_response :forbidden
  end

  test 'destroy removes only the current users item by target identity and is idempotent' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 2).delete_all
    QuickAccessItem.create!(user_id: 2, target_type: Issue.name, target_id: 2)

    assert_difference 'QuickAccessItem.count', -1 do
      delete :destroy, params: {target_type: 'Issue', target_id: 2}, xhr: true
    end
    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Issue', target_id: 2}, xhr: true
    end
    assert_response :success
    assert_equal 0, QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 2).count
    assert_includes response.body, 'quick-access-toggle-issue-2'
    assert_includes response.body, "quick-access-preview:invalidate"
  end

  test 'destroy does not reveal or remove another users item' do
    QuickAccessItem.where(target_type: 'Issue', target_id: 2).delete_all
    other_pin = QuickAccessItem.create!(user_id: 3, target_type: Issue.name, target_id: 2)

    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Issue', target_id: 2}, xhr: true
    end

    assert_response :success
    assert QuickAccessItem.exists?(other_pin.id)
  end

  test 'destroy rejects unsupported types without changing quick_access_items' do
    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Project', target_id: 1}, xhr: true
    end
    assert_response :not_found
  end

  test 'destroy redirects HTML back and succeeds when no own item exists' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    @request.env['HTTP_REFERER'] = issue_url(1)

    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Issue', target_id: 1}
    end

    assert_redirected_to issue_url(1)
  end

  test 'login is required for write actions' do
    @request.session[:user_id] = nil

    post :create, params: {target_type: 'Issue', target_id: 1}
    assert_redirected_to signin_url(back_url: quick_access_items_url)

    delete :destroy, params: {target_type: 'Issue', target_id: 1}
    assert_redirected_to signin_url(back_url: quick_access_items_url)
  end
end
