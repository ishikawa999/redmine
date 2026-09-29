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

require_relative '../test_helper'

class QuickAccessItemsHelperTest < Redmine::HelperTest
  include QuickAccessItemsHelper
  include IssueStatusesHelper

  def test_renders_a_create_or_delete_link_with_a_stable_dom_id_for_every_target_type
    User.current = users(:users_002)
    targets = [issues(:issues_001), wiki_pages(:wiki_pages_001), versions(:versions_001)]

    targets.each do |target|
      type = target.class.base_class.name
      dom_id = "quick-access-toggle-#{type.underscore.dasherize}-#{target.id}"
      href = quick_access_items_path(target_type: type, target_id: target.id)
      User.current.quick_access_items.where(target: target).delete_all

      assert_select_in quick_access_link(target),
                        "a##{dom_id}[href='#{href}'][data-remote='true'][data-method='post']" do
        assert_select '.quick-access-toggle.icon-link-add'
        assert_select 'a.quick-access-toggle svg.icon-svg'
        assert_select 'a.quick-access-toggle', text: 'Add to quick access'
      end

      User.current.quick_access_items.create!(target: target)
      assert_select_in quick_access_link(target),
                        "a##{dom_id}[href='#{href}'][data-remote='true'][data-method='delete']" do
        assert_select '.quick-access-toggle.icon-link-break'
        assert_select 'a.quick-access-toggle svg.icon-svg'
        assert_select 'a.quick-access-toggle', text: 'Remove from quick access'
      end
    end
  ensure
    User.current = nil
  end

  def test_resolves_current_display_information_for_every_supported_target_type
    issue = issues(:issues_001)
    wiki_page = wiki_pages(:wiki_pages_001)
    version = versions(:versions_001)

    assert_equal ["#{issue.tracker} ##{issue.id} #{issue.subject}", issue.project, issue_path(issue), 'Issue'],
                 [quick_access_label(issue), quick_access_project(issue), quick_access_path_for(issue), quick_access_type_label(issue)]
    assert_equal [wiki_page.pretty_title, wiki_page.project,
                  project_wiki_page_path(wiki_page.project, wiki_page.title), 'Wiki page'],
                 [quick_access_label(wiki_page), quick_access_project(wiki_page), quick_access_path_for(wiki_page), quick_access_type_label(wiki_page)]
    assert_equal [version.name, version.project, version_path(version), 'Version'],
                 [quick_access_label(version), quick_access_project(version), quick_access_path_for(version), quick_access_type_label(version)]
  end

  def test_status_label_carries_the_current_state_name_and_wiki_pages_carry_none
    issue = issues(:issues_001)
    version = versions(:versions_001)

    assert_equal issue.status.name, quick_access_status_label(issue)
    assert_equal l("version_status_#{version.status}"), quick_access_status_label(version)
    assert_nil quick_access_status_label(wiki_pages(:wiki_pages_001))
  end

  def test_status_badge_reports_open_and_closed_state_for_issues_only
    open_issue = issues(:issues_001)
    closed_issue = issues(:issues_008)
    assert_not open_issue.closed?
    assert closed_issue.closed?

    assert_select_in quick_access_status_badge(open_issue),
                     'span.badge.badge-status-open', text: l(:label_open_issues)
    assert_select_in quick_access_status_badge(closed_issue),
                     'span.badge.badge-status-closed', text: l(:label_closed_issues)

    # Versions and wiki pages carry no badge; a version's state is left to the
    # status column of the list.
    assert_nil quick_access_status_badge(versions(:versions_001))
    assert_nil quick_access_status_badge(wiki_pages(:wiki_pages_001))
  end

  def test_item_target_link_escapes_the_current_target_name
    issue = issues(:issues_001)
    issue.subject = '<script>alert("quick_access_items")</script>'

    link = quick_access_target_link(issue)

    assert_not_includes link, '<script>'
    assert_includes link, '&lt;script&gt;alert(&quot;quick_access_items&quot;)&lt;/script&gt;'
    assert_select_in link, "a[href='#{issue_path(issue)}']", count: 1
  end

  def test_state_labels_are_available_in_english_and_japanese
    expected = {
      en: ['Loading quick access items...', 'You have not added anything to quick access yet.', 'Could not load quick access items.'],
      ja: ['クイックアクセスを読み込み中...', 'クイックアクセスに登録した項目はありません。', 'クイックアクセスを取得できませんでした。']
    }

    expected.each do |locale, labels|
      I18n.with_locale(locale) do
        keys = [:label_loading_quick_access_items, :label_no_quick_access_items, :label_quick_access_load_error]
        assert_equal labels, keys.map {|key| l(key)}
      end
    end
  end
end
