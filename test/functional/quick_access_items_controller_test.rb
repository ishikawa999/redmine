# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../test_helper'

class QuickAccessItemsControllerTest < Redmine::ControllerTest
  setup do
    @request.session[:user_id] = 2
  end

  def test_routes_index_and_preview_through_separate_read_endpoints
    assert_routing({method: :get, path: '/quick_access'},
                   {controller: 'quick_access_items', action: 'index'})
    assert_routing({method: :get, path: '/quick_access/preview'},
                   {controller: 'quick_access_items', action: 'preview'})
  end

  def test_login_is_required_for_read_actions
    @request.session[:user_id] = nil

    get :index
    assert_redirected_to signin_url(back_url: quick_access_items_url)

    get :preview
    assert_redirected_to signin_url(back_url: quick_access_items_url)
  end

  def test_index_assigns_all_quick_access_items_returned_by_the_visible_reader
    visible_items = [quick_access_items(:quick_access_items_001), quick_access_items(:quick_access_items_002), quick_access_items(:quick_access_items_003)]
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns(visible_items)
    @controller.stubs(:default_render)

    get :index

    assert_response :success
    assert_equal visible_items, @controller.instance_variable_get(:@quick_access_items)
  end

  def test_index_lists_project_type_name_and_status_in_that_order
    item = quick_access_items(:quick_access_items_001)
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns([item])

    get :index

    assert_response :success
    assert_select 'table.quick-access thead th' do |headers|
      assert_equal [I18n.t(:label_project), I18n.t(:field_type), I18n.t(:field_name), I18n.t(:field_status), ''],
                   headers.map {|header| header.text.strip}
    end
    assert_select 'table.quick-access tbody tr' do
      assert_select 'td.quick-access-project a', text: item.target.project.name
      assert_select 'td.quick-access-type', text: I18n.t(:label_issue)
      assert_select 'td.quick-access-name a', text: @controller.helpers.quick_access_label(item.target)
      # The list spells the state out rather than reducing it to open/closed.
      assert_select 'td.quick-access-status', text: item.target.status.name
      assert_select 'td.quick-access-name .badge', count: 0
    end
  end

  def test_index_leaves_the_status_cell_empty_for_a_wiki_page
    item = quick_access_items(:quick_access_items_002)
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns([item])

    get :index

    assert_response :success
    assert_select 'table.quick-access tbody tr td.quick-access-status', text: ''
  end

  def test_index_assigns_an_empty_collection_when_no_item_is_visible
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns([])

    get :index

    assert_response :success
    assert_empty @controller.instance_variable_get(:@quick_access_items)
  end

  def test_index_paginates_the_visible_items_with_the_per_page_option
    visible_items = [quick_access_items(:quick_access_items_001), quick_access_items(:quick_access_items_002), quick_access_items(:quick_access_items_003)]
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns(visible_items)

    with_settings per_page_options: '2,25' do
      get :index, params: {per_page: 2, page: 2}
    end

    assert_response :success
    assert_equal [quick_access_items(:quick_access_items_003)], @controller.instance_variable_get(:@quick_access_items)
    assert_select 'table.quick-access tbody tr', count: 1
    assert_select 'span.pagination' do
      assert_select 'li.current', text: '2'
      assert_select 'li.previous a[href=?]', quick_access_items_path(page: 1, per_page: 2)
    end
  end

  def test_index_shows_the_last_page_for_a_page_beyond_it
    visible_items = [quick_access_items(:quick_access_items_001), quick_access_items(:quick_access_items_002), quick_access_items(:quick_access_items_003)]
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns(visible_items)

    with_settings per_page_options: '2,25' do
      get :index, params: {per_page: 2, page: 3}
    end

    assert_response :success
    assert_equal [quick_access_items(:quick_access_items_003)], @controller.instance_variable_get(:@quick_access_items)
    assert_select 'span.pagination li.current', text: '2'
  end

  def test_preview_renders_the_localized_empty_state_in_english_and_japanese
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT + 1).twice.returns([])

    [:en, :ja].each do |locale|
      I18n.with_locale(locale) do
        get :preview

        assert_response :success
        assert_select 'p.nodata', text: I18n.t(:label_no_quick_access_items)
      end
    end
  end

  def test_index_renders_direct_escaped_links_and_current_project_for_all_target_types
    quick_access_items = [quick_access_items(:quick_access_items_001), quick_access_items(:quick_access_items_002), quick_access_items(:quick_access_items_003)]
    quick_access_items.first.target.subject = '<script>issue</script>'
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns(quick_access_items)

    get :index

    assert_response :success
    assert_select 'table.quick-access tbody tr', count: 3
    assert_select 'table.quick-access td.buttons a svg.icon-svg', count: 3
    assert_select 'table.quick-access td.buttons a', text: 'Remove from quick access', count: 3
    assert_select "a[href='#{issue_path(quick_access_items[0].target)}']", text: /<script>issue<\/script>/
    assert_select "a[href='#{project_wiki_page_path(quick_access_items[1].target.project, quick_access_items[1].target.title)}']"
    assert_select "a[href='#{version_path(quick_access_items[2].target)}']"
    assert_not_includes response.body, '<script>issue</script>'
    quick_access_items.each do |item|
      assert_select "a[href='#{project_path(item.target.project)}']", text: item.target.project.name
    end
  end

  def test_preview_renders_direct_escaped_links_for_all_target_types
    quick_access_items = [quick_access_items(:quick_access_items_001), quick_access_items(:quick_access_items_002), quick_access_items(:quick_access_items_003)]
    quick_access_items[1].target.title = '<script>wiki</script>'
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT + 1).returns(quick_access_items)

    get :preview

    assert_response :success
    assert_select 'ul.quick-access-preview-items li.quick-access-preview-item', count: 3
    assert_select "a[href='#{issue_path(quick_access_items[0].target)}']"
    assert_select "a[href='#{project_wiki_page_path(quick_access_items[1].target.project, quick_access_items[1].target.title)}']"
    assert_select "a[href='#{version_path(quick_access_items[2].target)}']"
    assert_not_includes response.body, '<script>wiki</script>'
  end

  def test_index_excludes_invisible_and_orphaned_quick_access_items_without_deleting_them
    issue_item = quick_access_items(:quick_access_items_001)
    orphaned_pin = quick_access_items(:quick_access_items_002)
    Issue.any_instance.stubs(:visible?).with(User.find(2)).returns(false)
    orphaned_pin.update_columns(target_id: 999_999)
    @controller.stubs(:default_render)

    assert_no_difference 'QuickAccessItem.count' do
      get :index
    end

    assert_response :success
    assert_equal [quick_access_items(:quick_access_items_003)], @controller.instance_variable_get(:@quick_access_items)
    assert QuickAccessItem.exists?(issue_item.id)
    assert QuickAccessItem.exists?(orphaned_pin.id)
  end

  def test_preview_assigns_the_quick_access_items_in_reader_order_and_returns_an_html_fragment
    ordered_items = [quick_access_items(:quick_access_items_001), quick_access_items(:quick_access_items_002), quick_access_items(:quick_access_items_003)]
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT + 1).returns(ordered_items)

    get :preview

    assert_response :success
    assert_equal 'text/html', response.media_type
    assert_equal ordered_items, @controller.instance_variable_get(:@quick_access_items)
    assert_not response.body.include?('<html')
    assert_select 'ul.quick-access-preview-items' do
      assert_select 'li.quick-access-preview-item', count: 3
      assert_select 'li:last-child.quick-access-preview-more' do
        assert_select 'a[href=?]', '/quick_access', text: I18n.t(:label_view_all_quick_access_items)
      end
    end

    # Every item fits, so there is nothing left out to point at.
    assert_select 'p.quick-access-preview-heading', 0

    # A row reads as name, then project, then type, with an issue's state
    # trailing the type.
    issue_item = quick_access_items(:quick_access_items_001)
    within_row = "li.quick-access-preview-item[data-quick-access-id=?]"
    assert_select within_row, issue_item.id.to_s do
      assert_select '> a', text: @controller.helpers.quick_access_label(issue_item.target)
      assert_select '> span.quick-access-preview-project', text: issue_item.target.project.name
      assert_select '> span.quick-access-preview-type' do
        assert_select 'span.badge.badge-status-open', text: I18n.t(:label_open_issues)
      end
      assert_select '> span.quick-access-preview-type', text: /\A#{I18n.t(:label_issue)}\s/
    end
    # Only issues carry a badge; a version's state is left to the status column
    # of the list, and wiki pages have no state at all.
    {
      quick_access_items(:quick_access_items_003) => I18n.t(:label_version),
      quick_access_items(:quick_access_items_002) => I18n.t(:label_wiki_page)
    }.each do |other, type_label|
      assert_select within_row, other.id.to_s do
        assert_select '> span.quick-access-preview-type', text: type_label
        assert_select '> span.quick-access-preview-type .badge', count: 0
      end
    end
    rendered_items = css_select('li.quick-access-preview-item')
    rendered_ids = rendered_items.map {|element| element['data-quick-access-id'].to_i}
    assert_equal ordered_items.map(&:id), rendered_ids
    assert_equal ordered_items.map {|item| @controller.helpers.quick_access_label(item.target)},
                 rendered_items.map {|item| item.at_css('a').text}
  end

  def test_preview_says_how_many_are_shown_when_older_items_are_left_out
    quick_access_items = Array.new(QuickAccessItem::PREVIEW_LIMIT + 1) { quick_access_items(:quick_access_items_001) }
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT + 1).returns(quick_access_items)

    get :preview

    assert_response :success
    assert_select 'li.quick-access-preview-item', QuickAccessItem::PREVIEW_LIMIT
    assert_select 'p.quick-access-preview-heading',
                  text: I18n.t(:label_latest_quick_access_items, count: QuickAccessItem::PREVIEW_LIMIT)
  end

  def test_a_preview_reader_failure_is_isolated_from_the_full_page_endpoint
    QuickAccessItem::VisibleReader.any_instance.stubs(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT + 1).raises('preview failed')
    QuickAccessItem::VisibleReader.any_instance.stubs(:call).with(limit: nil).returns([])

    assert_raises(RuntimeError) { get :preview }

    get :index
    assert_response :success
    assert_empty @controller.instance_variable_get(:@quick_access_items)
  end

  def test_routes_destroy_only_through_the_target_identity_collection_endpoint
    assert_routing({method: :delete, path: '/quick_access'},
                   {controller: 'quick_access_items', action: 'destroy'})
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/quick_access/1', method: :delete)
    end
  end

  def test_create_quick_access_items_a_visible_issue_with_a_javascript_response_and_is_idempotent
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

  def test_create_redirects_html_back_to_a_safe_referring_page
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    @request.env['HTTP_REFERER'] = issue_url(1)

    post :create, params: {target_type: 'Issue', target_id: 1}

    assert_redirected_to issue_url(1)
    assert_equal 1, QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).count
  end

  def test_create_accepts_each_allowlisted_target_type
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

  def test_create_redirects_html_to_quick_access_items_when_the_referring_page_is_external
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    @request.env['HTTP_REFERER'] = 'https://attacker.example/path'

    post :create, params: {target_type: 'Issue', target_id: 1}

    assert_redirected_to quick_access_items_url
  end

  def test_create_rejects_unsupported_types
    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Project', target_id: 1}, xhr: true
    end
    assert_response :not_found
  end

  def test_create_rejects_a_missing_supported_target
    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 999_999}, xhr: true
    end
    assert_response :not_found
  end

  def test_create_rejects_an_invisible_target
    Issue.any_instance.stubs(:visible?).with(User.find(2)).returns(false)

    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 1}, xhr: true
    end
    assert_response :forbidden
  end

  def test_destroy_removes_only_the_current_users_item_by_target_identity_and_is_idempotent
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

  def test_destroy_does_not_reveal_or_remove_another_users_item
    QuickAccessItem.where(target_type: 'Issue', target_id: 2).delete_all
    other_pin = QuickAccessItem.create!(user_id: 3, target_type: Issue.name, target_id: 2)

    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Issue', target_id: 2}, xhr: true
    end

    assert_response :success
    assert QuickAccessItem.exists?(other_pin.id)
  end

  def test_destroy_rejects_unsupported_types_without_changing_quick_access_items
    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Project', target_id: 1}, xhr: true
    end
    assert_response :not_found
  end

  def test_destroy_redirects_html_back_and_succeeds_when_no_own_item_exists
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    @request.env['HTTP_REFERER'] = issue_url(1)

    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Issue', target_id: 1}
    end

    assert_redirected_to issue_url(1)
  end

  def test_login_is_required_for_write_actions
    @request.session[:user_id] = nil

    post :create, params: {target_type: 'Issue', target_id: 1}
    assert_redirected_to signin_url(back_url: quick_access_items_url)

    delete :destroy, params: {target_type: 'Issue', target_id: 1}
    assert_redirected_to signin_url(back_url: quick_access_items_url)
  end
end
