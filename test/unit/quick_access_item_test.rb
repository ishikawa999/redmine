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

  test 'destroying a target deletes its quick_access_items' do
    [issues(:issues_002), wiki_pages(:wiki_pages_001), versions(:versions_001)].each do |target|
      assert_difference('QuickAccessItem.count', -1) do
        target.destroy!
      end
    end
  end

  test 'returns every visible item in deterministic recent order' do
    user = users(:users_002)

    assert_equal [quick_access_items(:issue_item), quick_access_items(:wiki_page_item), quick_access_items(:version_item)],
                 QuickAccessItem.visible_for(user)
  end

  test 'visible_for returns the latest visible items up to the limit' do
    user = users(:users_007)
    timestamp = Time.current.change(usec: 0)
    visible_versions = create_versions_and_items(user, projects(:projects_001), 5, timestamp - 1.hour)
    create_versions_and_items(user, projects(:projects_002), 6, timestamp)

    result = QuickAccessItem.visible_for(user, limit: 5)

    assert_equal visible_versions.reverse.map(&:id), result.map(&:id)
  end

  test 'permission loss and recovery hides and restores a item without deleting it' do
    user = users(:users_007)
    version = create_version(projects(:projects_002), 'Private target')
    item = QuickAccessItem.create!(user: user, target: version)

    assert_empty QuickAccessItem.visible_for(user)
    assert QuickAccessItem.exists?(item.id)

    Member.create!(project: version.project, principal: user, roles: [roles(:roles_001)])
    user.reload

    assert_equal [item.id], QuickAccessItem.visible_for(user).map(&:id)
    assert QuickAccessItem.exists?(item.id)
  end

  test 'skips orphaned quick_access_items without changing stored quick_access_items' do
    user = users(:users_007)
    orphan_id = QuickAccessItem.maximum(:id) + 1
    QuickAccessItem.insert!({id: orphan_id,
      user_id: user.id,
      target_type: 'Issue',
      target_id: Issue.maximum(:id) + 100,
      created_at: Time.current,
      updated_at: Time.current})

    assert_empty QuickAccessItem.visible_for(user)
    assert QuickAccessItem.exists?(orphan_id)
  end

  test 'returns current target metadata' do
    user = users(:users_002)
    issue = quick_access_items(:issue_item).target
    issue.update_columns(subject: 'Current subject', status_id: 5)

    result = QuickAccessItem.visible_for(user)
    issue_item = result.find {|item| item.id == quick_access_items(:issue_item).id}
    version_item = result.find {|item| item.id == quick_access_items(:version_item).id}

    assert_equal 'Current subject', issue_item.target.subject
    assert issue_item.target.closed?
    assert_equal 'closed', version_item.target.status
  end

  test 'uses existing visibility for locked versions in a closed project' do
    user = users(:users_002)
    project = projects(:projects_001)
    project.close
    version = create_version(project, 'Locked version in closed project')
    version.update!(status: 'locked')
    item = QuickAccessItem.create!(user: user, target: version)

    assert version.visible?(user)
    assert_equal item.id, QuickAccessItem.visible_for(user).first.id
  end

  test 'excludes but retains a version shared into a visible project when its owner is invisible' do
    user = users(:users_007)
    shared_project = projects(:projects_001)
    owning_project = projects(:projects_002)
    version = create_version(owning_project, 'Shared from invisible owner')
    item = QuickAccessItem.create!(user: user, target: version)

    assert shared_project.visible?(user)
    assert_includes shared_project.shared_versions, version
    assert_not owning_project.visible?(user)
    assert_not version.visible?(user)

    assert_empty QuickAccessItem.visible_for(user)
    assert QuickAccessItem.exists?(item.id)
  end

  private

  def create_versions_and_items(user, project, count, timestamp)
    Array.new(count) do |index|
      version = create_version(project, "Reader version #{project.id}-#{index}")
      QuickAccessItem.create!(user: user, target: version, created_at: timestamp + index.seconds)
    end
  end

  def create_version(project, name)
    Version.create!(project: project, name: name, status: 'closed', sharing: 'system')
  end
end
