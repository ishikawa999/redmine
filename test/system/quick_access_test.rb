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

require_relative '../application_system_test_case'

class QuickAccessTest < ApplicationSystemTestCase
  setup do
    QuickAccessItem.delete_all
    log_user 'jsmith', 'jsmith'
  end

  def test_quick_access_items_lists_revisits_and_unpins_each_supported_target_through_its_detail_ui
    targets = [
      ['/issues/2', '#quick-access-toggle-issue-2', 'Issue', '#2 Add ingredients categories'],
      ['/projects/ecookbook/wiki/CookBook_documentation', '#quick-access-toggle-wiki-page-1', 'Wiki page', 'CookBook documentation'],
      ['/versions/1', '#quick-access-toggle-version-1', 'Version', '0.1']
    ]

    targets.each do |path, toggle, type, name|
      visit path
      open_contextual_actions_dropdown
      find(toggle, match: :first, text: 'Add to quick access').click
      assert_selector toggle, text: 'Remove from quick access'

      visit '/quick_access'
      within('table.quick-access tbody tr') do
        assert_text type
        assert_text name
        assert_text 'eCookbook'
        assert_link name, href: path
        click_link name
      end
      assert_current_path path

      open_contextual_actions_dropdown
      find(toggle, match: :first, text: 'Remove from quick access').click
      assert_selector toggle, text: 'Add to quick access'
    end

    assert_empty User.find(2).quick_access_items
  end

  def test_lists_current_metadata_revisits_targets_and_puts_a_repinned_target_first
    issue = Issue.find(2)
    wiki_page = WikiPage.find(1)
    version = Version.find(1)
    [
      ['/issues/2', '#quick-access-toggle-issue-2'],
      ['/projects/ecookbook/wiki/CookBook_documentation', '#quick-access-toggle-wiki-page-1'],
      ['/versions/1', '#quick-access-toggle-version-1']
    ].each do |path, toggle|
      visit path
      open_contextual_actions_dropdown
      find(toggle, match: :first, text: 'Add to quick access').click
      assert_selector toggle, text: 'Remove from quick access'
    end

    issue.update!(subject: 'Current ingredients title')
    visit '/quick_access'

    assert_selector 'table.quick-access tbody tr', count: 3
    assert_text 'Current ingredients title'
    assert_text wiki_page.pretty_title
    assert_text version.name
    assert_text issue.project.name

    click_link 'Current ingredients title'
    assert_current_path '/issues/2'

    open_contextual_actions_dropdown
    find('#quick-access-toggle-issue-2', match: :first, text: 'Remove from quick access').click
    assert_selector '#quick-access-toggle-issue-2', text: 'Add to quick access'
    find('#quick-access-toggle-issue-2', match: :first, text: 'Add to quick access').click
    visit '/quick_access'

    within('table.quick-access tbody tr:first-child') do
      assert_text 'Current ingredients title'
    end
  end

  def test_does_not_display_or_remove_another_users_item
    other_pin = User.find(3).quick_access_items.create!(target: Issue.find(2))

    visit '/quick_access'

    assert_text 'You have not added anything to quick access yet.'
    assert_no_selector "a[href='/issues/2']"
    assert QuickAccessItem.exists?(other_pin.id)
  end

  def test_item_operations_do_not_change_notifications_priority_or_assignee
    issue = Issue.find(2)
    before_state = [issue.priority_id, issue.assigned_to_id, issue.watcher_user_ids.sort]

    visit '/issues/2'
    open_contextual_actions_dropdown
    find('#quick-access-toggle-issue-2', match: :first, text: 'Add to quick access').click
    find('#quick-access-toggle-issue-2', match: :first, text: 'Remove from quick access').click

    issue.reload
    assert_equal before_state, [issue.priority_id, issue.assigned_to_id, issue.watcher_user_ids.sort]
  end

  def test_roadmap_does_not_offer_version_item_controls
    visit '/projects/ecookbook/roadmap'

    assert_no_selector '[id^="quick-access-toggle-version-"]'
    # Scoped to #content: a plain 'Add to quick access' locator also substring-matches the
    # unrelated top-nav "Quick access" link.
    within('#content') do
      assert_no_link 'Add to quick access'
      assert_no_link 'Remove from quick access'
    end
  end
end

# The item toggle is a plain remote <a> (Rails UJS), so it needs JavaScript
# to submit as POST/DELETE; only the identity-route authorization check
# below is independent of that and still worth covering without a browser.
class PersonalPinsNoJavascriptTest < ActionDispatch::SystemTestCase
  driven_by :rack_test, options: {respect_data_method: false}

  setup do
    QuickAccessItem.delete_all
    visit '/login'
    fill_in 'username', with: 'jsmith'
    fill_in 'password', with: 'jsmith'
    click_button 'Login'
  end

  def test_cannot_remove_another_users_item_through_the_identity_route
    other_pin = User.find(3).quick_access_items.create!(target: Issue.find(2))

    visit '/quick_access'
    page.driver.submit :delete, '/quick_access', target_type: 'Issue', target_id: 2

    assert_equal 200, page.status_code
    assert_current_path '/quick_access'
    assert QuickAccessItem.exists?(other_pin.id)
    assert_text 'You have not added anything to quick access yet.'
    assert_no_link '#2 Add ingredients categories'
    assert_no_selector '#errorExplanation, #flash_error'

    page.driver.submit :delete, '/quick_access', target_type: 'Issue', target_id: 1

    assert_equal 200, page.status_code
    assert_current_path '/quick_access'
    assert_text 'You have not added anything to quick access yet.'
    assert_no_selector '#errorExplanation, #flash_error'
    assert QuickAccessItem.exists?(other_pin.id)
  end
end
