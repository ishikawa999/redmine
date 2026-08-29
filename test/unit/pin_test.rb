# frozen_string_literal: true

require_relative '../test_helper'

class PinTest < ActiveSupport::TestCase
  fixtures :pins, :users, :issues, :projects, :members, :member_roles, :roles,
           :wikis, :wiki_pages, :versions

  test 'issue wiki page and version are supported pinnable types' do
    supported_pinnables = [issues(:issues_001), wiki_pages(:wiki_pages_001), versions(:versions_001)]

    supported_pinnables.each do |pinnable|
      pin = Pin.new(user: users(:users_003), pinnable: pinnable)
      assert pin.valid?, "#{pinnable.class.name} should be supported: #{pin.errors.full_messages.join(', ')}"
    end
  end

  test 'unsupported object types cannot be pinned' do
    pin = Pin.new(user: users(:users_002), pinnable_type: 'Project', pinnable_id: 1)
    assert_not pin.valid?
    assert pin.errors[:pinnable_type].present?
  end

  test 'an object can only be pinned once per user' do
    existing = pins(:issue_pin)
    duplicate = Pin.new(user: existing.user, pinnable: existing.pinnable)
    assert_not duplicate.valid?
    assert duplicate.errors[:pinnable_id].present?
  end

  test 'visibility follows the pinned object permissions' do
    assert pins(:issue_pin).visible?(users(:users_002))
    private_issue_pin = Pin.new(user: users(:users_002), pinnable: issues(:issues_014))
    assert_not private_issue_pin.visible?(User.anonymous)
  end

  test 'recent first orders pins deterministically by creation time then id' do
    timestamp = Time.current.change(usec: 0)
    older = Pin.create!(user: users(:users_003), pinnable: issues(:issues_001), created_at: timestamp - 1.minute)
    same_time_first = Pin.create!(user: users(:users_003), pinnable: issues(:issues_002), created_at: timestamp)
    same_time_last = Pin.create!(user: users(:users_003), pinnable: issues(:issues_003), created_at: timestamp)

    assert_equal [same_time_last, same_time_first, older],
                 Pin.where(id: [older.id, same_time_first.id, same_time_last.id]).recent_first.to_a
  end

  test 'creating a pin does not change issue notifications priority or assignee' do
    issue = issues(:issues_001)
    state_before = [issue.watcher_user_ids.sort, issue.priority_id, issue.assigned_to_id]

    Pin.create!(user: users(:users_003), pinnable: issue)

    issue.reload
    assert_equal state_before, [issue.watcher_user_ids.sort, issue.priority_id, issue.assigned_to_id]
  end
end
