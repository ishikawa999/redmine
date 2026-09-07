# frozen_string_literal: true

module QuickAccessMenuHelper
  def render_top_menu
    links = menu_items_for(:top_menu).map do |node|
      if node.name == :quick_access
        render_quick_access_menu_node(node)
      else
        render_menu_node(node)
      end
    end

    content_tag(:ul, safe_join(links)) if links.any?
  end

  private

  def render_quick_access_menu_node(node)
    caption, url, selected = extract_node_details(node)
    link = render_single_menu_node(node, caption, url, selected)
    preview = content_tag(
      :div,
      nil,
      class: 'quick-access-preview',
      data: {'quick-access-preview-target': 'preview', state: 'idle'},
      aria: {live: 'polite'}
    )

    content_tag(
      :li,
      safe_join([link, preview]),
      class: 'quick-access-menu',
      data: {
        controller: 'quick-access-preview',
        'quick-access-preview-url-value': preview_quick_access_items_path,
        'quick-access-preview-loading-text-value': l(:label_loading_quick_access_items),
        'quick-access-preview-error-text-value': l(:label_quick_access_load_error)
      }
    )
  end
end
