# frozen_string_literal: true

require_relative '../test_helper'

class QuickAccessItemTest < ActiveSupport::TestCase
  fixtures :quick_access_items, :users, :issues, :projects, :members, :member_roles, :roles,
           :wikis, :wiki_pages, :versions

  test 'issue wiki page and version are supported target types' do
    supported_targets = [issues(:issues_001), wiki_pages(:wiki_pages_001), versions(:versions_001)]

    supported_targets.each do |target|
      item = QuickAccessItem.new(user: users(:users_003), target: target)
      assert item.valid?, "#{target.class.name} should be supported: #{item.errors.full_messages.join(', ')}"
    end
  end

  test 'unsupported object types cannot be added to quick access' do
    item = QuickAccessItem.new(user: users(:users_002), target_type: 'Project', target_id: 1)
    assert_not item.valid?
    assert item.errors[:target_type].present?
  end

  test 'an object can only be added to quick access once per user' do
    existing = quick_access_items(:issue_item)
    duplicate = QuickAccessItem.new(user: existing.user, target: existing.target)
    assert_not duplicate.valid?
    assert duplicate.errors[:target_id].present?
  end

  test 'visibility follows the target object permissions' do
    assert quick_access_items(:issue_item).visible?(users(:users_002))
    private_issue_item = QuickAccessItem.new(user: users(:users_002), target: issues(:issues_014))
    assert_not private_issue_item.visible?(User.anonymous)
  end

  test 'recent first orders quick_access_items deterministically by creation time then id' do
    timestamp = Time.current.change(usec: 0)
    older = QuickAccessItem.create!(user: users(:users_003), target: issues(:issues_001), created_at: timestamp - 1.minute)
    same_time_first = QuickAccessItem.create!(user: users(:users_003), target: issues(:issues_002), created_at: timestamp)
    same_time_last = QuickAccessItem.create!(user: users(:users_003), target: issues(:issues_003), created_at: timestamp)

    assert_equal [same_time_last, same_time_first, older],
                 QuickAccessItem.where(id: [older.id, same_time_first.id, same_time_last.id]).recent_first.to_a
  end

  test 'creating a item does not change issue notifications priority or assignee' do
    issue = issues(:issues_001)
    state_before = [issue.watcher_user_ids.sort, issue.priority_id, issue.assigned_to_id]

    QuickAccessItem.create!(user: users(:users_003), target: issue)

    issue.reload
    assert_equal state_before, [issue.watcher_user_ids.sort, issue.priority_id, issue.assigned_to_id]
  end

  test 'users and supported targets expose their quick_access_items' do
    assert_includes users(:users_002).quick_access_items, quick_access_items(:issue_item)
    assert_includes issues(:issues_002).quick_access_items, quick_access_items(:issue_item)
    assert_includes wiki_pages(:wiki_pages_001).quick_access_items, quick_access_items(:wiki_page_item)
    assert_includes versions(:versions_001).quick_access_items, quick_access_items(:version_item)
  end

  test 'destroying an issue deletes only its quick_access_items' do
    issue_item_id = quick_access_items(:issue_item).id
    assert_difference('QuickAccessItem.count', -1) do
      issues(:issues_002).destroy!
    end

    assert_not QuickAccessItem.exists?(issue_item_id)
    assert QuickAccessItem.exists?(quick_access_items(:wiki_page_item).id)
    assert QuickAccessItem.exists?(quick_access_items(:version_item).id)
  end

  test 'destroying a wiki page deletes only its quick_access_items' do
    wiki_page_item_id = quick_access_items(:wiki_page_item).id
    assert_difference('QuickAccessItem.count', -1) do
      wiki_pages(:wiki_pages_001).destroy!
    end

    assert QuickAccessItem.exists?(quick_access_items(:issue_item).id)
    assert_not QuickAccessItem.exists?(wiki_page_item_id)
    assert QuickAccessItem.exists?(quick_access_items(:version_item).id)
  end

  test 'destroying a version deletes only its quick_access_items' do
    version_item_id = quick_access_items(:version_item).id
    assert_difference('QuickAccessItem.count', -1) do
      versions(:versions_001).destroy!
    end

    assert QuickAccessItem.exists?(quick_access_items(:issue_item).id)
    assert QuickAccessItem.exists?(quick_access_items(:wiki_page_item).id)
    assert_not QuickAccessItem.exists?(version_item_id)
  end
end
