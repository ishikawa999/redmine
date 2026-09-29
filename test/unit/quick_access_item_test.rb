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

class QuickAccessItemTest < ActiveSupport::TestCase
  def test_issue_wiki_page_and_version_are_supported_target_types
    supported_targets = [issues(:issues_001), wiki_pages(:wiki_pages_001), versions(:versions_001)]

    supported_targets.each do |target|
      item = QuickAccessItem.new(user: users(:users_003), target: target)
      assert item.valid?, "#{target.class.name} should be supported: #{item.errors.full_messages.join(', ')}"
    end
  end

  def test_unsupported_object_types_cannot_be_added_to_quick_access
    item = QuickAccessItem.new(user: users(:users_002), target_type: 'Project', target_id: 1)
    assert_not item.valid?
    assert item.errors[:target_type].present?
  end

  def test_an_object_can_only_be_added_to_quick_access_once_per_user
    existing = quick_access_items(:quick_access_items_001)
    duplicate = QuickAccessItem.new(user: existing.user, target: existing.target)
    assert_not duplicate.valid?
    assert duplicate.errors[:target_id].present?
  end

  def test_recent_first_orders_quick_access_items_deterministically_by_creation_time_then_id
    timestamp = Time.current.change(usec: 0)
    older = QuickAccessItem.create!(user: users(:users_003), target: issues(:issues_001), created_at: timestamp - 1.minute)
    same_time_first = QuickAccessItem.create!(user: users(:users_003), target: issues(:issues_002), created_at: timestamp)
    same_time_last = QuickAccessItem.create!(user: users(:users_003), target: issues(:issues_003), created_at: timestamp)

    assert_equal [same_time_last, same_time_first, older],
                 QuickAccessItem.where(id: [older.id, same_time_first.id, same_time_last.id]).recent_first.to_a
  end

  def test_creating_a_item_does_not_change_issue_notifications_priority_or_assignee
    issue = issues(:issues_001)
    state_before = [issue.watcher_user_ids.sort, issue.priority_id, issue.assigned_to_id]

    QuickAccessItem.create!(user: users(:users_003), target: issue)

    issue.reload
    assert_equal state_before, [issue.watcher_user_ids.sort, issue.priority_id, issue.assigned_to_id]
  end

  def test_users_and_supported_targets_expose_their_quick_access_items
    assert_includes users(:users_002).quick_access_items, quick_access_items(:quick_access_items_001)
    assert_includes issues(:issues_002).quick_access_items, quick_access_items(:quick_access_items_001)
    assert_includes wiki_pages(:wiki_pages_001).quick_access_items, quick_access_items(:quick_access_items_002)
    assert_includes versions(:versions_001).quick_access_items, quick_access_items(:quick_access_items_003)
  end

  def test_destroying_an_issue_deletes_only_its_quick_access_items
    issue_item_id = quick_access_items(:quick_access_items_001).id
    assert_difference('QuickAccessItem.count', -1) do
      issues(:issues_002).destroy!
    end

    assert_not QuickAccessItem.exists?(issue_item_id)
    assert QuickAccessItem.exists?(quick_access_items(:quick_access_items_002).id)
    assert QuickAccessItem.exists?(quick_access_items(:quick_access_items_003).id)
  end

  def test_destroying_a_wiki_page_deletes_only_its_quick_access_items
    wiki_page_item_id = quick_access_items(:quick_access_items_002).id
    assert_difference('QuickAccessItem.count', -1) do
      wiki_pages(:wiki_pages_001).destroy!
    end

    assert QuickAccessItem.exists?(quick_access_items(:quick_access_items_001).id)
    assert_not QuickAccessItem.exists?(wiki_page_item_id)
    assert QuickAccessItem.exists?(quick_access_items(:quick_access_items_003).id)
  end

  def test_destroying_a_version_deletes_only_its_quick_access_items
    version_item_id = quick_access_items(:quick_access_items_003).id
    assert_difference('QuickAccessItem.count', -1) do
      versions(:versions_001).destroy!
    end

    assert QuickAccessItem.exists?(quick_access_items(:quick_access_items_001).id)
    assert QuickAccessItem.exists?(quick_access_items(:quick_access_items_002).id)
    assert_not QuickAccessItem.exists?(version_item_id)
  end
end
