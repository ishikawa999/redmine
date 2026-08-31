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
      within(find(toggle, match: :first)) { click_button 'Pin' }
      all(toggle).each {|element| within(element) { assert_button 'Unpin' }}

      visit '/pins'
      within('table.pinned-items tbody tr') do
        assert_text type
        assert_text name
        assert_text 'eCookbook'
        assert_link name, href: path
        click_link name
      end
      assert_current_path path

      within(find(toggle, match: :first)) { click_button 'Unpin' }
      all(toggle).each {|element| within(element) { assert_button 'Pin' }}
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
      within(find(toggle, match: :first)) { click_button 'Pin' }
      all(toggle).each {|element| within(element) { assert_button 'Unpin' }}
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

    within(find('#pin-toggle-issue-2', match: :first)) { click_button 'Unpin' }
    all('#pin-toggle-issue-2').each {|element| within(element) { assert_button 'Pin' }}
    within(find('#pin-toggle-issue-2', match: :first)) { click_button 'Pin' }
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
    within(find('#pin-toggle-issue-2', match: :first)) { click_button 'Pin' }
    within(find('#pin-toggle-issue-2', match: :first)) { click_button 'Unpin' }

    issue.reload
    assert_equal before_state, [issue.priority_id, issue.assigned_to_id, issue.watcher_user_ids.sort]
  end

  test 'roadmap does not offer version pin controls' do
    visit '/projects/ecookbook/roadmap'

    assert_no_selector '[id^="pin-toggle-version-"]'
    assert_no_button 'Pin'
    assert_no_button 'Unpin'
  end
end

class PersonalPinsNoJavascriptTest < ActionDispatch::SystemTestCase
  driven_by :rack_test, options: {respect_data_method: false}

  setup do
    Pin.delete_all
    visit '/login'
    fill_in 'username', with: 'jsmith'
    fill_in 'password', with: 'jsmith'
    click_button 'Login'
  end

  test 'adds removes and opens the list through ordinary html navigation' do
    visit '/issues/2'
    click_button 'Pin', match: :first

    assert_current_path '/issues/2'
    assert_button 'Unpin'
    click_link 'Pinned items'
    assert_current_path '/pins'
    assert_link '#2 Add ingredients categories', href: '/issues/2'

    click_button 'Unpin'
    assert_current_path '/pins'
    assert_text 'You have not pinned anything yet.'
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
