# frozen_string_literal: true

require_relative '../application_system_test_case'

class QuickAccessTest < ApplicationSystemTestCase
  setup do
    QuickAccessItem.delete_all
    log_user 'jsmith', 'jsmith'
  end

  test 'add and remove quick access items from issue, wiki page and version pages' do
    targets = [
      ['/issues/2', '#quick-access-toggle-issue-2', 'Issue', '#2 Add ingredients categories'],
      ['/projects/ecookbook/wiki/CookBook_documentation', '#quick-access-toggle-wiki-page-1', 'Wiki page', 'CookBook documentation'],
      ['/versions/1', '#quick-access-toggle-version-1', 'Version', '0.1']
    ]

    targets.each do |path, toggle, type, name|
      visit path
      open_actions_dropdown
      find(toggle, text: 'Add to quick access').click
      assert_selector toggle, text: 'Remove from quick access'

      visit '/quick_access'
      within('table.quick-access tbody tr') do
        assert_text type
        assert_text 'eCookbook'
        click_link name
      end
      assert_current_path path

      open_actions_dropdown
      find(toggle, text: 'Remove from quick access').click
      assert_selector toggle, text: 'Add to quick access'
    end

    assert_empty User.find(2).quick_access_items
  end

  test 'account menu shows the latest quick access items' do
    User.find(2).quick_access_items.create!(target: Issue.find(2))
    visit '/projects/ecookbook'

    find('#account .dropdown-trigger').click
    find('#account li.quick-access-menu').hover
    within('.quick-access-preview') do
      assert_selector '.quick-access-preview-item', count: 1
      click_link '#2 Add ingredients categories'
    end
    assert_current_path '/issues/2'
  end

  test 'switching to the mobile layout keeps the loaded items inside the submenu' do
    User.find(2).quick_access_items.create!(target: Issue.find(2))
    visit '/projects/ecookbook'
    find('#account .dropdown-trigger').click
    find('#account li.quick-access-menu').hover
    assert_selector '.quick-access-preview-item', count: 1

    page.current_window.resize_to(500, 800)
    assert_selector '.flyout-menu .js-profile-menu > ul', count: 1, visible: :all
    page.current_window.resize_to(1024, 900)
    assert_selector '#account .dropdown-content > ul', count: 1, visible: :all
    assert_selector '.quick-access-preview > ul.quick-access-preview-items', visible: :all
  ensure
    page.current_window.resize_to(1024, 900)
  end

  private

  def open_actions_dropdown
    find('#content .contextual .dropdown-trigger', match: :first).click
  end
end
