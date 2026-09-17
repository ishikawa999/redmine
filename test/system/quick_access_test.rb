# frozen_string_literal: true

require_relative '../application_system_test_case'

class QuickAccessTest < ApplicationSystemTestCase
  setup do
    QuickAccessItem.delete_all
    log_user 'jsmith', 'jsmith'
  end

  test 'quick_access_items lists revisits and unpins each supported target through its detail UI' do
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

  test 'lists current metadata revisits targets and puts a repinned target first' do
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

  test 'does not display or remove another users item' do
    other_pin = User.find(3).quick_access_items.create!(target: Issue.find(2))

    visit '/quick_access'

    assert_text 'You have not added anything to quick access yet.'
    assert_no_selector "a[href='/issues/2']"
    assert QuickAccessItem.exists?(other_pin.id)
  end

  test 'item operations do not change notifications priority or assignee' do
    issue = Issue.find(2)
    before_state = [issue.priority_id, issue.assigned_to_id, issue.watcher_user_ids.sort]

    visit '/issues/2'
    open_contextual_actions_dropdown
    find('#quick-access-toggle-issue-2', match: :first, text: 'Add to quick access').click
    find('#quick-access-toggle-issue-2', match: :first, text: 'Remove from quick access').click

    issue.reload
    assert_equal before_state, [issue.priority_id, issue.assigned_to_id, issue.watcher_user_ids.sort]
  end

  test 'roadmap does not offer version item controls' do
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

  test 'cannot remove another users item through the identity route' do
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
