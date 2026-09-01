# frozen_string_literal: true

require_relative '../application_system_test_case'

class PersonalPinsTest < ApplicationSystemTestCase
  setup do
    Pin.delete_all
    log_user 'jsmith', 'jsmith'
  end

  test 'pins lists revisits and unpins each supported target through its detail UI' do
    targets = [
      ['/issues/2', '#pin-toggle-issue-2', 'Issue', '#2 Add ingredients categories'],
      ['/projects/ecookbook/wiki/CookBook_documentation', '#pin-toggle-wiki-page-1', 'Wiki page', 'CookBook documentation'],
      ['/versions/1', '#pin-toggle-version-1', 'Version', '0.1']
    ]

    targets.each do |path, toggle, type, name|
      visit path
      open_contextual_actions_dropdown
      find(toggle, match: :first, text: 'Pin').click
      assert_selector toggle, text: 'Unpin'

      visit '/pins'
      within('table.pinned-items tbody tr') do
        assert_text type
        assert_text name
        assert_text 'eCookbook'
        assert_link name, href: path
        click_link name
      end
      assert_current_path path

      open_contextual_actions_dropdown
      find(toggle, match: :first, text: 'Unpin').click
      assert_selector toggle, text: 'Pin'
    end

    assert_empty User.find(2).pins
  end

  test 'lists current metadata revisits targets and puts a repinned target first' do
    issue = Issue.find(2)
    wiki_page = WikiPage.find(1)
    version = Version.find(1)
    [
      ['/issues/2', '#pin-toggle-issue-2'],
      ['/projects/ecookbook/wiki/CookBook_documentation', '#pin-toggle-wiki-page-1'],
      ['/versions/1', '#pin-toggle-version-1']
    ].each do |path, toggle|
      visit path
      open_contextual_actions_dropdown
      find(toggle, match: :first, text: 'Pin').click
      assert_selector toggle, text: 'Unpin'
    end

    issue.update!(subject: 'Current ingredients title')
    visit '/pins'

    assert_selector 'table.pinned-items tbody tr', count: 3
    assert_text 'Current ingredients title'
    assert_text wiki_page.pretty_title
    assert_text version.name
    assert_text issue.project.name

    click_link 'Current ingredients title'
    assert_current_path '/issues/2'

    open_contextual_actions_dropdown
    find('#pin-toggle-issue-2', match: :first, text: 'Unpin').click
    assert_selector '#pin-toggle-issue-2', text: 'Pin'
    find('#pin-toggle-issue-2', match: :first, text: 'Pin').click
    visit '/pins'

    within('table.pinned-items tbody tr:first-child') do
      assert_text 'Current ingredients title'
    end
  end

  test 'does not display or remove another users pin' do
    other_pin = User.find(3).pins.create!(pinnable: Issue.find(2))

    visit '/pins'

    assert_text 'You have not pinned anything yet.'
    assert_no_selector "a[href='/issues/2']"
    assert Pin.exists?(other_pin.id)
  end

  test 'pin operations do not change notifications priority or assignee' do
    issue = Issue.find(2)
    before_state = [issue.priority_id, issue.assigned_to_id, issue.watcher_user_ids.sort]

    visit '/issues/2'
    open_contextual_actions_dropdown
    find('#pin-toggle-issue-2', match: :first, text: 'Pin').click
    find('#pin-toggle-issue-2', match: :first, text: 'Unpin').click

    issue.reload
    assert_equal before_state, [issue.priority_id, issue.assigned_to_id, issue.watcher_user_ids.sort]
  end

  test 'roadmap does not offer version pin controls' do
    visit '/projects/ecookbook/roadmap'

    assert_no_selector '[id^="pin-toggle-version-"]'
    # Scoped to #content: a plain 'Pin' locator also substring-matches the
    # unrelated top-nav "Pinned items" link.
    within('#content') do
      assert_no_link 'Pin'
      assert_no_link 'Unpin'
    end
  end
end

# The pin toggle is a plain remote <a> (Rails UJS), so it needs JavaScript
# to submit as POST/DELETE; only the identity-route authorization check
# below is independent of that and still worth covering without a browser.
class PersonalPinsNoJavascriptTest < ActionDispatch::SystemTestCase
  driven_by :rack_test, options: {respect_data_method: false}

  setup do
    Pin.delete_all
    visit '/login'
    fill_in 'username', with: 'jsmith'
    fill_in 'password', with: 'jsmith'
    click_button 'Login'
  end

  test 'cannot remove another users pin through the identity route' do
    other_pin = User.find(3).pins.create!(pinnable: Issue.find(2))

    visit '/pins'
    page.driver.submit :delete, '/pins', pinnable_type: 'Issue', pinnable_id: 2

    assert_equal 200, page.status_code
    assert_current_path '/pins'
    assert Pin.exists?(other_pin.id)
    assert_text 'You have not pinned anything yet.'
    assert_no_link '#2 Add ingredients categories'
    assert_no_selector '#errorExplanation, #flash_error'

    page.driver.submit :delete, '/pins', pinnable_type: 'Issue', pinnable_id: 1

    assert_equal 200, page.status_code
    assert_current_path '/pins'
    assert_text 'You have not pinned anything yet.'
    assert_no_selector '#errorExplanation, #flash_error'
    assert Pin.exists?(other_pin.id)
  end
end
