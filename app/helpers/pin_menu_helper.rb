# frozen_string_literal: true

module PinMenuHelper
  def render_top_menu
    links = menu_items_for(:top_menu).map do |node|
      if node.name == :pinned_items
        render_pinned_items_menu_node(node)
      else
        render_menu_node(node)
      end
    end

    content_tag(:ul, safe_join(links)) if links.any?
  end

  private

  def render_pinned_items_menu_node(node)
    caption, url, selected = extract_node_details(node)
    link = render_single_menu_node(node, caption, url, selected)
    preview = content_tag(
      :div,
      nil,
      class: 'pin-preview',
      data: {'pin-preview-target': 'preview', state: 'idle'},
      aria: {live: 'polite'}
    )

    content_tag(
      :li,
      safe_join([link, preview]),
      class: 'pinned-items-menu',
      data: {
        controller: 'pin-preview',
        'pin-preview-url-value': preview_pins_path,
        'pin-preview-loading-text-value': l(:label_loading_pinned_items),
        'pin-preview-error-text-value': l(:label_pinned_items_load_error)
      }
    )
  end
end
