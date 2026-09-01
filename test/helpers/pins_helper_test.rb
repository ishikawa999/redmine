# frozen_string_literal: true

require_relative '../test_helper'

class PinsHelperTest < Redmine::HelperTest
  include PinsHelper

  fixtures :pins, :users, :issues, :projects, :members, :member_roles, :roles,
           :trackers, :issue_statuses, :enumerations,
           :wikis, :wiki_pages, :versions

  test 'renders progressively enhanced create and identity delete forms for every target type' do
    User.current = users(:users_002)
    targets = [issues(:issues_001), wiki_pages(:wiki_pages_001), versions(:versions_001)]

    targets.each do |target|
      type = target.class.base_class.name
      User.current.pins.where(pinnable: target).delete_all

      assert_select_in pin_link(target), "form[action='#{pins_path}'][method='post'][data-remote='true']" do
        assert_select "input[name='pinnable_type'][value='#{type}']"
        assert_select "input[name='pinnable_id'][value='#{target.id}']"
        assert_select '.pin-toggle.icon-pin-off'
        assert_select 'button.pin-toggle svg.icon-svg'
        assert_select 'button.pin-toggle', text: 'Pin'
      end

      User.current.pins.create!(pinnable: target)
      assert_select_in pin_link(target), "form[action='#{pins_path}'][method='post'][data-remote='true']" do
        assert_select "input[name='_method'][value='delete']"
        assert_select "input[name='pinnable_type'][value='#{type}']"
        assert_select "input[name='pinnable_id'][value='#{target.id}']"
        assert_select '.pin-toggle.icon-pin'
        assert_select 'button.pin-toggle svg.icon-svg'
        assert_select 'button.pin-toggle', text: 'Unpin'
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
                 [pin_label(issue), pin_project(issue), pin_path_for(issue), pin_type_label(issue)]
    assert_equal [wiki_page.pretty_title, wiki_page.project,
                  project_wiki_page_path(wiki_page.project, wiki_page.title), 'Wiki page'],
                 [pin_label(wiki_page), pin_project(wiki_page), pin_path_for(wiki_page), pin_type_label(wiki_page)]
    assert_equal [version.name, version.project, version_path(version), 'Version'],
                 [pin_label(version), pin_project(version), pin_path_for(version), pin_type_label(version)]
  end

  test 'pin target link escapes the current target name' do
    issue = issues(:issues_001)
    issue.subject = '<script>alert("pins")</script>'

    link = pin_target_link(issue)

    assert_not_includes link, '<script>'
    assert_includes link, '&lt;script&gt;alert(&quot;pins&quot;)&lt;/script&gt;'
    assert_select_in link, "a[href='#{issue_path(issue)}']", count: 1
  end

  test 'state labels are available in English and Japanese' do
    expected = {
      en: ['Loading pinned items…', 'You have not pinned anything yet.', 'Could not load pinned items.'],
      ja: ['ピン留めを読み込み中…', 'ピン留めした項目はありません。', 'ピン留めを取得できませんでした。']
    }

    expected.each do |locale, labels|
      I18n.with_locale(locale) do
        keys = [:label_loading_pinned_items, :label_no_pinned_items, :label_pinned_items_load_error]
        assert_equal labels, keys.map {|key| l(key)}
      end
    end
  end
end
