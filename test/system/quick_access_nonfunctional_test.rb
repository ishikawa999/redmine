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

class QuickAccessNonfunctionalTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1024, 900)
    QuickAccessItem.delete_all
    log_user 'jsmith', 'jsmith'
    @user = User.find(2)
  end

  def test_permission_loss_hides_all_target_metadata_and_recovery_restores_the_same_quick_access_items
    project = Project.find(1)
    targets = [Issue.find(2), WikiPage.find(1), Version.find(1)]
    quick_access_items = targets.map {|target| @user.quick_access_items.create!(target: target)}
    paths = ['/issues/2', '/projects/ecookbook/wiki/CookBook_documentation', '/versions/1']

    visit '/quick_access'
    paths.each {|path| assert_selector "table.quick-access a[href='#{path}']"}

    project.update!(is_public: false)
    project.members.destroy_all
    assert_not project.visible?(@user.reload)
    visit '/quick_access'
    assert_text 'You have not added anything to quick access yet.'
    [targets[0].subject, targets[1].pretty_title, targets[2].name].each {|name| assert_no_text name}
    assert_no_text project.name
    paths.each {|path| assert_no_selector "#content a[href='#{path}']"}
    assert_equal quick_access_items.map(&:id).sort, @user.quick_access_items.order(:id).pluck(:id)

    Member.create!(project: project, principal: @user, roles: [Role.find(1)])
    visit '/quick_access'
    paths.each {|path| assert_selector "table.quick-access a[href='#{path}']"}
    assert_equal quick_access_items.map(&:id).sort, @user.quick_access_items.order(:id).pluck(:id)
  end

  def test_deleted_targets_including_orphaned_references_do_not_break_the_rendered_list
    deleted = Version.create!(project: Project.find(1), name: 'Deleted target version')
    orphan = Version.create!(project: Project.find(1), name: 'Orphaned target version')
    deleted_item = @user.quick_access_items.create!(target: deleted)
    orphan_item = @user.quick_access_items.create!(target: orphan)
    @user.quick_access_items.create!(target: Issue.find(2))
    deleted.destroy!
    orphan.delete

    visit '/quick_access'

    assert_selector 'table.quick-access tbody tr', count: 1
    assert_link '#2 Add ingredients categories', href: '/issues/2'
    [deleted, orphan].each do |target|
      assert_no_text target.name
      assert_no_selector "#content a[href='/versions/#{target.id}']"
    end
    assert_not QuickAccessItem.exists?(deleted_item.id)
    assert QuickAccessItem.exists?(orphan_item.id)
  end

  def test_current_names_and_moved_project_are_rendered_after_adding
    issue = Issue.find(2)
    wiki = WikiPage.find(1)
    version = Version.find(1)
    [issue, wiki, version].each {|target| @user.quick_access_items.create!(target: target)}
    issue.update!(subject: 'Renamed target issue', project: Project.find(3))
    wiki.update!(title: 'Renamed_target_wiki')
    version.update!(name: 'Renamed target version')
    Project.find(1).update!(name: 'Current source project')
    Project.find(3).update!(name: 'Current destination project')

    visit '/quick_access'

    within(find('table.quick-access tr', text: 'Renamed target issue')) do
      assert_link '#2 Renamed target issue', href: '/issues/2'
      assert_text 'Current destination project'
      assert_no_text 'Current source project'
    end
    within(find('table.quick-access tr', text: 'Renamed target wiki')) do
      assert_link 'Renamed target wiki', href: '/projects/ecookbook/wiki/Renamed_target_wiki'
      assert_text 'Current source project'
    end
    within(find('table.quick-access tr', text: 'Renamed target version')) do
      assert_link 'Renamed target version', href: '/versions/1'
      assert_text 'Current source project'
    end
    assert_no_text 'Add ingredients categories'
    assert_no_link 'CookBook documentation'
  end

  def test_closed_issues_locked_and_closed_versions_and_wiki_remain_listed_in_a_closed_project
    issue = Issue.find(2)
    issue.update!(status: IssueStatus.where(is_closed: true).first!)
    versions = %w[locked closed].map do |status|
      Version.create!(project: Project.find(1), name: "Target #{status} version", status: status)
    end
    targets = [issue, WikiPage.find(1), *versions]
    targets.each {|target| @user.quick_access_items.create!(target: target)}
    Project.find(1).close
    assert Project.find(1).closed?
    targets.each {|target| assert target.reload.visible?(@user.reload)}

    visit '/quick_access'

    assert_selector 'table.quick-access tbody tr', count: 4
    assert_link '#2 Add ingredients categories', href: '/issues/2'
    assert_link 'CookBook documentation', href: '/projects/ecookbook/wiki/CookBook_documentation'
    versions.each {|version| assert_link version.name, href: "/versions/#{version.id}"}
  end

  def test_a_shared_version_cannot_leak_from_an_invisible_owner_through_an_accessible_destination
    owner = Project.find(2)
    owner.members.destroy_all
    version = Version.create!(project: owner, name: 'Secret shared release', sharing: 'system')
    item = @user.quick_access_items.create!(target: version)
    assert_not owner.visible?(@user.reload)
    assert_includes Project.find(1).shared_versions, version

    visit '/projects/ecookbook/roadmap'
    assert_current_path '/projects/ecookbook/roadmap'
    assert_selector '#content h2', text: 'Roadmap'
    visit "/versions/#{version.id}"
    assert_no_selector '[id^="quick-access-toggle-version-"]'
    assert_selector '#content', text: /403|404/
    visit '/quick_access'

    assert_text 'You have not added anything to quick access yet.'
    assert_no_text version.name
    assert_no_text owner.name
    assert_no_selector "#content a[href='/versions/#{version.id}']"
    assert QuickAccessItem.exists?(item.id)
  end

  def test_initial_page_makes_no_preview_request_and_failed_preview_leaves_normal_search_usable
    script = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      window.quickAccessPreviewRequests = 0;
      const originalFetch = window.fetch.bind(window);
      window.fetch = function(url, options) {
        if (!String(url).includes('/quick_access/preview')) return originalFetch(url, options);
        window.quickAccessPreviewRequests += 1;
        return Promise.resolve(new Response('', {status: 503}));
      };
    JS
    visit '/projects/ecookbook'
    assert_selector '#content h2', text: 'Overview'
    # The node lives inside the closed account menu, so it is present but not
    # yet on screen.
    assert_selector 'li.quick-access-menu[data-controller="quick-access-preview"]', visible: :all
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
      page.evaluate_script(<<~JS)
        !!window.Stimulus?.getControllerForElementAndIdentifier(
          document.querySelector('li.quick-access-menu'), 'quick-access-preview'
        )
      JS
    end
    assert_equal 0, page.evaluate_script('window.quickAccessPreviewRequests')
    assert_selector '.quick-access-preview[data-state="idle"]', visible: :all

    find('#account .dropdown-trigger').click
    assert_selector '#account .dropdown-content:not(.hidden)'
    find('#account li.quick-access-menu').hover
    assert_selector '.quick-access-preview[data-state="error"]', text: 'Could not load quick access items.'
    assert_equal 1, page.evaluate_script('window.quickAccessPreviewRequests')
    assert_current_path '/projects/ecookbook'
    page.send_keys(:escape)
    fill_in 'q', with: 'ingredients'
    find('#q').send_keys(:enter)
    assert_current_path '/projects/ecookbook/search', ignore_query: true
    assert_selector '#content', text: 'Add ingredients categories'
  ensure
    page.driver.browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: script['identifier']) if script
  end
end
