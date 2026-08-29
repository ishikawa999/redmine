# frozen_string_literal: true

class Pin < ApplicationRecord
  PINNABLE_TYPES = %w[Issue WikiPage Version].freeze

  belongs_to :user
  belongs_to :pinnable, polymorphic: true

  validates :pinnable_type, inclusion: {in: PINNABLE_TYPES}
  validates :pinnable_id, uniqueness: {scope: [:user_id, :pinnable_type]}

  scope :recent_first, -> {order(created_at: :desc, id: :desc)}

  def visible?(user = User.current)
    pinnable.present? && pinnable.visible?(user)
  end
end
