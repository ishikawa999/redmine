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

require_relative '../../test_helper'

class QuickAccessItem::VisibleReaderTest < ActiveSupport::TestCase
  def test_returns_every_visible_item_in_deterministic_recent_order
    user = users(:users_002)

    assert_equal [quick_access_items(:quick_access_items_001), quick_access_items(:quick_access_items_002), quick_access_items(:quick_access_items_003)],
                 QuickAccessItem::VisibleReader.new(user).call
  end

  def test_continues_past_an_invisible_batch_to_return_the_latest_five_visible_quick_access_items
    user = users(:users_007)
    timestamp = Time.current.change(usec: 0)
    visible_versions = create_versions_and_items(user, projects(:projects_001), 5, timestamp - 1.hour)
    create_versions_and_items(user, projects(:projects_002), 6, timestamp)

    result = QuickAccessItem::VisibleReader.new(user).call(limit: 5)

    assert_equal visible_versions.reverse.map(&:id), result.map(&:id)
  end

  def test_reads_every_item_in_a_single_pass_without_a_limit
    user = users(:users_007)
    timestamp = Time.current.change(usec: 0)
    visible_versions = create_versions_and_items(user, projects(:projects_001), 12, timestamp - 1.hour)
    create_versions_and_items(user, projects(:projects_002), 12, timestamp)

    item_queries = 0
    count_item_queries = ->(*, payload) { item_queries += 1 if payload[:name] == 'QuickAccessItem Load' }
    result = ActiveSupport::Notifications.subscribed(count_item_queries, 'sql.active_record') do
      QuickAccessItem::VisibleReader.new(user).call
    end

    assert_equal visible_versions.reverse.map(&:id), result.map(&:id)
    assert_equal 1, item_queries
  end

  def test_permission_loss_and_recovery_hides_and_restores_a_item_without_deleting_it
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

  def test_skips_orphaned_quick_access_items_without_changing_stored_quick_access_items
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

  def test_returns_current_target_metadata_and_preloads_each_target_project_path
    user = users(:users_002)
    issue = quick_access_items(:quick_access_items_001).target
    issue.update_columns(subject: 'Current subject', status_id: 5)

    result = QuickAccessItem::VisibleReader.new(user).call
    issue_item = result.find {|item| item.id == quick_access_items(:quick_access_items_001).id}
    wiki_item = result.find {|item| item.id == quick_access_items(:quick_access_items_002).id}
    version_item = result.find {|item| item.id == quick_access_items(:quick_access_items_003).id}

    assert_equal 'Current subject', issue_item.target.subject
    assert issue_item.target.closed?
    assert issue_item.target.association(:project).loaded?
    assert wiki_item.target.association(:wiki).loaded?
    assert wiki_item.target.wiki.association(:project).loaded?
    assert version_item.target.association(:project).loaded?
    assert_equal 'closed', version_item.target.status
  end

  def test_uses_existing_visibility_for_locked_versions_in_a_closed_project
    user = users(:users_002)
    project = projects(:projects_001)
    project.close
    version = create_version(project, 'Locked version in closed project')
    version.update!(status: 'locked')
    item = QuickAccessItem.create!(user: user, target: version)

    assert version.visible?(user)
    assert_equal item.id, QuickAccessItem::VisibleReader.new(user).call.first.id
  end

  def test_excludes_but_retains_a_version_shared_into_a_visible_project_when_its_owner_is_invisible
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

  def test_rejects_non_positive_limits
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
