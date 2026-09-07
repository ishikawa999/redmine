# frozen_string_literal: true

class QuickAccessItem::VisibleReader
  BATCH_SIZE = 5

  def initialize(user)
    @user = user
  end

  def call(limit: nil)
    raise ArgumentError, "limit must be a positive integer" if limit && (!limit.is_a?(Integer) || limit <= 0)

    visible_items = []
    cursor = nil

    loop do
      batch = next_batch(cursor)
      break if batch.empty?

      preload_targets_and_projects(batch)
      batch.each do |item|
        visible_items << item if visible?(item)
        return visible_items if limit && visible_items.size == limit
      end

      last_item = batch.last
      cursor = [last_item.created_at, last_item.id]
    end

    visible_items
  end

  private

  def next_batch(cursor)
    scope = QuickAccessItem.where(user: @user).recent_first
    if cursor
      created_at, id = cursor
      scope = scope.where(
        "quick_access_items.created_at < :created_at OR (quick_access_items.created_at = :created_at AND quick_access_items.id < :id)",
        created_at: created_at,
        id: id
      )
    end
    scope.limit(BATCH_SIZE).to_a
  end

  def preload_targets_and_projects(quick_access_items)
    preload(quick_access_items, :target)

    targets = quick_access_items.filter_map(&:target)
    preload(targets.grep(Issue), :project)
    preload(targets.grep(Version), :project)

    wiki_pages = targets.grep(WikiPage)
    preload(wiki_pages, :wiki)
    preload(wiki_pages.filter_map(&:wiki), :project)
  end

  def preload(records, associations)
    return if records.empty?

    ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
  end

  def visible?(item)
    item.target.present? && item.target.visible?(@user)
  rescue ActiveRecord::RecordNotFound
    false
  end
end
