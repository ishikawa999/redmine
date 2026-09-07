# frozen_string_literal: true

class QuickAccessItem < ApplicationRecord
  TARGET_TYPES = %w[Issue WikiPage Version].freeze

  belongs_to :user
  belongs_to :target, polymorphic: true

  validates :target_type, inclusion: {in: TARGET_TYPES}
  validates :target_id, uniqueness: {scope: [:user_id, :target_type]}

  scope :recent_first, -> {order(created_at: :desc, id: :desc)}

  def visible?(user = User.current)
    target.present? && target.visible?(user)
  end
end
