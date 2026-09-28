# frozen_string_literal: true

class QuickAccessItem < ApplicationRecord
  TARGET_TYPES = %w[Issue WikiPage Version].freeze

  # Number of items listed in the account menu
  PREVIEW_LIMIT = 5

  belongs_to :user
  belongs_to :target, polymorphic: true

  validates :target_type, inclusion: {in: TARGET_TYPES}
  validates :target_id, uniqueness: {scope: [:user_id, :target_type]}

  scope :recent_first, -> {order(created_at: :desc, id: :desc)}

  # Returns the items of user whose target is visible to user, most recent first
  def self.visible_for(user, limit: nil)
    items = where(user: user).recent_first.preload(:target).to_a
    targets = items.filter_map(&:target)
    ActiveRecord::Associations::Preloader.new(records: targets.grep(Issue) + targets.grep(Version), associations: :project).call
    ActiveRecord::Associations::Preloader.new(records: targets.grep(WikiPage), associations: {:wiki => :project}).call

    items = items.select {|item| item.visible?(user)}
    limit ? items.first(limit) : items
  end

  def visible?(user = User.current)
    target.present? && target.visible?(user)
  end
end
