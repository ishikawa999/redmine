# frozen_string_literal: true

require_relative '../../test_helper'

class QuickAccessItem::VisibleReaderTest < ActiveSupport::TestCase
  fixtures :quick_access_items, :users, :issues, :projects, :members, :member_roles, :roles,
           :wikis, :wiki_pages, :versions

  test 'returns every visible item in deterministic recent order' do
    user = users(:users_002)

    assert_equal [quick_access_items(:issue_item), quick_access_items(:wiki_page_item), quick_access_items(:version_item)],
                 QuickAccessItem::VisibleReader.new(user).call
  end

  test 'continues past an invisible batch to return the latest five visible quick_access_items' do
    user = users(:users_007)
    timestamp = Time.current.change(usec: 0)
    visible_versions = create_versions_and_items(user, projects(:projects_001), 5, timestamp - 1.hour)
    create_versions_and_items(user, projects(:projects_002), 6, timestamp)

    result = QuickAccessItem::VisibleReader.new(user).call(limit: 5)

    assert_equal visible_versions.reverse.map(&:id), result.map(&:id)
  end

  test 'permission loss and recovery hides and restores a item without deleting it' do
    user = users(:users_007)
    version = create_version(projects(:projects_002), 'Private target')
    item = QuickAccessItem.create!(user: user, target: version)

    assert_empty QuickAccessItem::VisibleReader.new(user).call
    assert QuickAccessItem.exists?(item.id)

    Member.create!(project: version.project, principal: user, roles: [roles(:roles_001)])
    user.reload

    assert_equal [item.id], QuickAccessItem::VisibleReader.new(user).call.map(&:id)
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

    assert_empty QuickAccessItem::VisibleReader.new(user).call
    assert QuickAccessItem.exists?(orphan_id)
  end

  test 'returns current target metadata and preloads each target project path' do
    user = users(:users_002)
    issue = quick_access_items(:issue_item).target
    issue.update_columns(subject: 'Current subject', status_id: 5)

    result = QuickAccessItem::VisibleReader.new(user).call
    issue_item = result.find {|item| item.id == quick_access_items(:issue_item).id}
    wiki_item = result.find {|item| item.id == quick_access_items(:wiki_page_item).id}
    version_item = result.find {|item| item.id == quick_access_items(:version_item).id}

    assert_equal 'Current subject', issue_item.target.subject
    assert issue_item.target.closed?
    assert issue_item.target.association(:project).loaded?
    assert wiki_item.target.association(:wiki).loaded?
    assert wiki_item.target.wiki.association(:project).loaded?
    assert version_item.target.association(:project).loaded?
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
    assert_equal item.id, QuickAccessItem::VisibleReader.new(user).call.first.id
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

    assert_empty QuickAccessItem::VisibleReader.new(user).call
    assert QuickAccessItem.exists?(item.id)
  end

  test 'rejects non-positive limits' do
    assert_raises(ArgumentError) {QuickAccessItem::VisibleReader.new(users(:users_002)).call(limit: 0)}
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
