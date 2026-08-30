# frozen_string_literal: true

require_relative '../application_system_test_case'

class PersonalPinsNonfunctionalTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1024, 900)
    Pin.delete_all
    log_user 'jsmith', 'jsmith'
    @user = User.find(2)
  end

  test 'permission loss hides all target metadata and recovery restores the same pins' do
    project = Project.find(1)
    targets = [Issue.find(2), WikiPage.find(1), Version.find(1)]
    pins = targets.map {|target| @user.pins.create!(pinnable: target)}
    paths = ['/issues/2', '/projects/ecookbook/wiki/CookBook_documentation', '/versions/1']

    visit '/pins'
    paths.each {|path| assert_selector "table.pinned-items a[href='#{path}']"}

    project.update!(is_public: false)
    project.members.destroy_all
    assert_not project.visible?(@user.reload)
    visit '/pins'
    assert_text 'You have not pinned anything yet.'
    [targets[0].subject, targets[1].pretty_title, targets[2].name].each {|name| assert_no_text name}
    assert_no_text project.name
    paths.each {|path| assert_no_selector "#content a[href='#{path}']"}
    assert_equal pins.map(&:id).sort, @user.pins.order(:id).pluck(:id)

    Member.create!(project: project, principal: @user, roles: [Role.find(1)])
    visit '/pins'
    paths.each {|path| assert_selector "table.pinned-items a[href='#{path}']"}
    assert_equal pins.map(&:id).sort, @user.pins.order(:id).pluck(:id)
  end

  test 'deleted targets including orphaned references do not break the rendered list' do
    deleted = Version.create!(project: Project.find(1), name: 'Deleted pinned version')
    orphan = Version.create!(project: Project.find(1), name: 'Orphaned pinned version')
    deleted_pin = @user.pins.create!(pinnable: deleted)
    orphan_pin = @user.pins.create!(pinnable: orphan)
    @user.pins.create!(pinnable: Issue.find(2))
    deleted.destroy!
    orphan.delete

    visit '/pins'

    assert_selector 'table.pinned-items tbody tr', count: 1
    assert_link '#2 Add ingredients categories', href: '/issues/2'
    [deleted, orphan].each do |target|
      assert_no_text target.name
      assert_no_selector "#content a[href='/versions/#{target.id}']"
    end
    assert_not Pin.exists?(deleted_pin.id)
    assert Pin.exists?(orphan_pin.id)
  end

  test 'current names and moved project are rendered after pinning' do
    issue = Issue.find(2)
    wiki = WikiPage.find(1)
    version = Version.find(1)
    [issue, wiki, version].each {|target| @user.pins.create!(pinnable: target)}
    issue.update!(subject: 'Renamed pinned issue', project: Project.find(3))
    wiki.update!(title: 'Renamed_pinned_wiki')
    version.update!(name: 'Renamed pinned version')
    Project.find(1).update!(name: 'Current source project')
    Project.find(3).update!(name: 'Current destination project')

    visit '/pins'

    within(find('table.pinned-items tr', text: 'Renamed pinned issue')) do
      assert_link '#2 Renamed pinned issue', href: '/issues/2'
      assert_text 'Current destination project'
      assert_no_text 'Current source project'
    end
    within(find('table.pinned-items tr', text: 'Renamed pinned wiki')) do
      assert_link 'Renamed pinned wiki', href: '/projects/ecookbook/wiki/Renamed_pinned_wiki'
      assert_text 'Current source project'
    end
    within(find('table.pinned-items tr', text: 'Renamed pinned version')) do
      assert_link 'Renamed pinned version', href: '/versions/1'
      assert_text 'Current source project'
    end
    assert_no_text 'Add ingredients categories'
    assert_no_link 'CookBook documentation'
  end

  test 'closed issues locked and closed versions and wiki remain listed in a closed project' do
    issue = Issue.find(2)
    issue.update!(status: IssueStatus.where(is_closed: true).first!)
    versions = %w[locked closed].map do |status|
      Version.create!(project: Project.find(1), name: "Pinned #{status} version", status: status)
    end
    targets = [issue, WikiPage.find(1), *versions]
    targets.each {|target| @user.pins.create!(pinnable: target)}
    Project.find(1).close
    assert Project.find(1).closed?
    targets.each {|target| assert target.reload.visible?(@user.reload)}

    visit '/pins'

    assert_selector 'table.pinned-items tbody tr', count: 4
    assert_link '#2 Add ingredients categories', href: '/issues/2'
    assert_link 'CookBook documentation', href: '/projects/ecookbook/wiki/CookBook_documentation'
    versions.each {|version| assert_link version.name, href: "/versions/#{version.id}"}
  end

  test 'a shared version cannot leak from an invisible owner through an accessible destination' do
    owner = Project.find(2)
    owner.members.destroy_all
    version = Version.create!(project: owner, name: 'Secret shared release', sharing: 'system')
    pin = @user.pins.create!(pinnable: version)
    assert_not owner.visible?(@user.reload)
    assert_includes Project.find(1).shared_versions, version

    visit '/projects/ecookbook/roadmap'
    assert_current_path '/projects/ecookbook/roadmap'
    assert_selector '#content h2', text: 'Roadmap'
    visit "/versions/#{version.id}"
    assert_no_selector '[id^="pin-toggle-version-"]'
    assert_selector '#content', text: /403|404/
    visit '/pins'

    assert_text 'You have not pinned anything yet.'
    assert_no_text version.name
    assert_no_text owner.name
    assert_no_selector "#content a[href='/versions/#{version.id}']"
    assert Pin.exists?(pin.id)
  end

  test 'initial page makes no preview request and failed preview leaves normal search usable' do
    script = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      window.pinPreviewRequests = 0;
      const originalFetch = window.fetch.bind(window);
      window.fetch = function(url, options) {
        if (!String(url).includes('/pins/preview')) return originalFetch(url, options);
        window.pinPreviewRequests += 1;
        return Promise.resolve(new Response('', {status: 503}));
      };
    JS
    visit '/projects/ecookbook'
    assert_selector '#content h2', text: 'Overview'
    assert_selector 'li.pinned-items-menu[data-controller="pin-preview"]'
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
      page.evaluate_script(<<~JS)
        !!window.Stimulus?.getControllerForElementAndIdentifier(
          document.querySelector('li.pinned-items-menu'), 'pin-preview'
        )
      JS
    end
    assert_equal 0, page.evaluate_script('window.pinPreviewRequests')
    assert_selector '.pin-preview[data-state="idle"]', visible: :all

    find('li.pinned-items-menu').hover
    assert_selector '.pin-preview[data-state="error"]', text: 'Could not load pinned items.'
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
