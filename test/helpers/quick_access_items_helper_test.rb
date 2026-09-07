# frozen_string_literal: true

require_relative '../test_helper'

class QuickAccessItemsHelperTest < Redmine::HelperTest
  include QuickAccessItemsHelper

  fixtures :quick_access_items, :users, :issues, :projects, :members, :member_roles, :roles,
           :trackers, :issue_statuses, :enumerations,
           :wikis, :wiki_pages, :versions

  test 'renders a create or delete link with a stable dom id for every target type' do
    User.current = users(:users_002)
    targets = [issues(:issues_001), wiki_pages(:wiki_pages_001), versions(:versions_001)]

    targets.each do |target|
      type = target.class.base_class.name
      dom_id = "quick-access-toggle-#{type.underscore.dasherize}-#{target.id}"
      href = quick_access_items_path(target_type: type, target_id: target.id)
      User.current.quick_access_items.where(target: target).delete_all

      assert_select_in quick_access_link(target),
                        "a##{dom_id}[href='#{href}'][data-remote='true'][data-method='post']" do
        assert_select '.quick-access-toggle.icon-pin-off'
        assert_select 'a.quick-access-toggle svg.icon-svg'
        assert_select 'a.quick-access-toggle', text: 'Add to quick access'
      end

      User.current.quick_access_items.create!(target: target)
      assert_select_in quick_access_link(target),
                        "a##{dom_id}[href='#{href}'][data-remote='true'][data-method='delete']" do
        assert_select '.quick-access-toggle.icon-pin'
        assert_select 'a.quick-access-toggle svg.icon-svg'
        assert_select 'a.quick-access-toggle', text: 'Remove from quick access'
      end
    end
  ensure
    User.current = nil
  end

  test 'resolves current display information for every supported target type' do
    issue = issues(:issues_001)
    wiki_page = wiki_pages(:wiki_pages_001)
    version = versions(:versions_001)

    assert_equal ["##{issue.id} #{issue.subject}", issue.project, issue_path(issue), 'Issue'],
                 [quick_access_label(issue), quick_access_project(issue), quick_access_path_for(issue), quick_access_type_label(issue)]
    assert_equal [wiki_page.pretty_title, wiki_page.project,
                  project_wiki_page_path(wiki_page.project, wiki_page.title), 'Wiki page'],
                 [quick_access_label(wiki_page), quick_access_project(wiki_page), quick_access_path_for(wiki_page), quick_access_type_label(wiki_page)]
    assert_equal [version.name, version.project, version_path(version), 'Version'],
                 [quick_access_label(version), quick_access_project(version), quick_access_path_for(version), quick_access_type_label(version)]
  end

  test 'item target link escapes the current target name' do
    issue = issues(:issues_001)
    issue.subject = '<script>alert("quick_access_items")</script>'

    link = quick_access_target_link(issue)

    assert_not_includes link, '<script>'
    assert_includes link, '&lt;script&gt;alert(&quot;quick_access_items&quot;)&lt;/script&gt;'
    assert_select_in link, "a[href='#{issue_path(issue)}']", count: 1
  end

  test 'state labels are available in English and Japanese' do
    expected = {
      en: ['Loading quick access items…', 'You have not added anything to quick access yet.', 'Could not load quick access items.'],
      ja: ['クイックアクセスを読み込み中…', 'クイックアクセスに登録した項目はありません。', 'クイックアクセスを取得できませんでした。']
    }

    expected.each do |locale, labels|
      I18n.with_locale(locale) do
        keys = [:label_loading_quick_access_items, :label_no_quick_access_items, :label_quick_access_load_error]
        assert_equal labels, keys.map {|key| l(key)}
      end
    end
  end
end
