# frozen_string_literal: true

require_relative '../../test_helper'

class Pin::VisibleReaderTest < ActiveSupport::TestCase
  fixtures :pins, :users, :issues, :projects, :members, :member_roles, :roles,
           :wikis, :wiki_pages, :versions

  test 'returns every visible pin in deterministic recent order' do
    user = users(:users_002)

    assert_equal [pins(:issue_pin), pins(:wiki_page_pin), pins(:version_pin)],
                 Pin::VisibleReader.new(user).call
  end

  test 'continues past an invisible batch to return the latest five visible pins' do
    user = users(:users_007)
    timestamp = Time.current.change(usec: 0)
    visible_versions = create_versions_and_pins(user, projects(:projects_001), 5, timestamp - 1.hour)
    create_versions_and_pins(user, projects(:projects_002), 6, timestamp)

    result = Pin::VisibleReader.new(user).call(limit: 5)

    assert_equal visible_versions.reverse.map(&:id), result.map(&:id)
  end

  test 'permission loss and recovery hides and restores a pin without deleting it' do
    user = users(:users_007)
    version = create_version(projects(:projects_002), 'Private target')
    pin = Pin.create!(user: user, pinnable: version)

    assert_empty Pin::VisibleReader.new(user).call
    assert Pin.exists?(pin.id)

    Member.create!(project: version.project, principal: user, roles: [roles(:roles_001)])
    user.reload

    assert_equal [pin.id], Pin::VisibleReader.new(user).call.map(&:id)
    assert Pin.exists?(pin.id)
  end

  test 'skips orphaned pins without changing stored pins' do
    user = users(:users_007)
    orphan_id = Pin.maximum(:id) + 1
    Pin.insert!({id: orphan_id,
      user_id: user.id,
      pinnable_type: 'Issue',
      pinnable_id: Issue.maximum(:id) + 100,
      created_at: Time.current,
      updated_at: Time.current})

    assert_empty Pin::VisibleReader.new(user).call
    assert Pin.exists?(orphan_id)
  end

  test 'returns current target metadata and preloads each target project path' do
    user = users(:users_002)
    issue = pins(:issue_pin).pinnable
    issue.update_columns(subject: 'Current subject', status_id: 5)

    result = Pin::VisibleReader.new(user).call
    issue_pin = result.find {|pin| pin.id == pins(:issue_pin).id}
    wiki_pin = result.find {|pin| pin.id == pins(:wiki_page_pin).id}
    version_pin = result.find {|pin| pin.id == pins(:version_pin).id}

    assert_equal 'Current subject', issue_pin.pinnable.subject
    assert issue_pin.pinnable.closed?
    assert issue_pin.pinnable.association(:project).loaded?
    assert wiki_pin.pinnable.association(:wiki).loaded?
    assert wiki_pin.pinnable.wiki.association(:project).loaded?
    assert version_pin.pinnable.association(:project).loaded?
    assert_equal 'closed', version_pin.pinnable.status
  end

  test 'uses existing visibility for locked versions in a closed project' do
    user = users(:users_002)
    project = projects(:projects_001)
    project.close
    version = create_version(project, 'Locked version in closed project')
    version.update!(status: 'locked')
    pin = Pin.create!(user: user, pinnable: version)

    assert version.visible?(user)
    assert_equal pin.id, Pin::VisibleReader.new(user).call.first.id
  end

  test 'excludes but retains a version shared into a visible project when its owner is invisible' do
    user = users(:users_007)
    shared_project = projects(:projects_001)
    owning_project = projects(:projects_002)
    version = create_version(owning_project, 'Shared from invisible owner')
    pin = Pin.create!(user: user, pinnable: version)

    assert shared_project.visible?(user)
    assert_includes shared_project.shared_versions, version
    assert_not owning_project.visible?(user)
    assert_not version.visible?(user)

    assert_empty Pin::VisibleReader.new(user).call
    assert Pin.exists?(pin.id)
  end

  test 'rejects non-positive limits' do
    assert_raises(ArgumentError) {Pin::VisibleReader.new(users(:users_002)).call(limit: 0)}
  end

  private

  def create_versions_and_pins(user, project, count, timestamp)
    Array.new(count) do |index|
      version = create_version(project, "Reader version #{project.id}-#{index}")
      Pin.create!(user: user, pinnable: version, created_at: timestamp + index.seconds)
    end
  end

  def create_version(project, name)
    Version.create!(project: project, name: name, status: 'closed', sharing: 'system')
  end
end
