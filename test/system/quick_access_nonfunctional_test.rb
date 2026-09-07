# frozen_string_literal: true

require_relative '../application_system_test_case'

class QuickAccessNonfunctionalTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1024, 900)
    QuickAccessItem.delete_all
    log_user 'jsmith', 'jsmith'
    @user = User.find(2)
  end

  test 'permission loss hides all target metadata and recovery restores the same quick_access_items' do
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

  test 'deleted targets including orphaned references do not break the rendered list' do
    deleted = Version.create!(project: Project.find(1), name: 'Deleted target version')
    orphan = Version.create!(project: Project.find(1), name: 'Orphaned target version')
    deleted_pin = @user.quick_access_items.create!(target: deleted)
    orphan_pin = @user.quick_access_items.create!(target: orphan)
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
    assert_not QuickAccessItem.exists?(deleted_pin.id)
    assert QuickAccessItem.exists?(orphan_pin.id)
  end

  test 'current names and moved project are rendered after pinning' do
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

  test 'closed issues locked and closed versions and wiki remain listed in a closed project' do
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

  test 'a shared version cannot leak from an invisible owner through an accessible destination' do
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

  test 'initial page makes no preview request and failed preview leaves normal search usable' do
    script = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      window.pinPreviewRequests = 0;
      const originalFetch = window.fetch.bind(window);
      window.fetch = function(url, options) {
        if (!String(url).includes('/quick_access/preview')) return originalFetch(url, options);
        window.pinPreviewRequests += 1;
        return Promise.resolve(new Response('', {status: 503}));
      };
    JS
    visit '/projects/ecookbook'
    assert_selector '#content h2', text: 'Overview'
    assert_selector 'li.quick-access-menu[data-controller="quick-access-preview"]'
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
      page.evaluate_script(<<~JS)
        !!window.Stimulus?.getControllerForElementAndIdentifier(
          document.querySelector('li.quick-access-menu'), 'quick-access-preview'
        )
      JS
    end
    assert_equal 0, page.evaluate_script('window.pinPreviewRequests')
    assert_selector '.quick-access-preview[data-state="idle"]', visible: :all

    find('li.quick-access-menu').hover
    assert_selector '.quick-access-preview[data-state="error"]', text: 'Could not load quick access items.'
    assert_equal 1, page.evaluate_script('window.pinPreviewRequests')
    assert_current_path '/projects/ecookbook'
    fill_in 'q', with: 'ingredients'
    find('#q').send_keys(:enter)
    assert_current_path '/projects/ecookbook/search', ignore_query: true
    assert_selector '#content', text: 'Add ingredients categories'
  ensure
    page.driver.browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: script['identifier']) if script
  end
end
