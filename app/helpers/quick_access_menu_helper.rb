# frozen_string_literal: true

module QuickAccessMenuHelper
  # Renders the account menu. The quick access node carries a nested submenu
  # that opens alongside it, listing the most recently added items.
  def render_account_menu
    links = menu_items_for(:account_menu).map do |node|
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
    # The account menu sits against the trailing edge of the window, so the
    # submenu opens towards the leading edge and its marker points that way.
    marker = sprite_icon('angle-left', size: 12, css_class: 'quick-access-submenu-marker')
    link = render_single_menu_node(node, safe_join([marker, caption]), url, selected)
    preview = content_tag(
      :div,
      nil,
      :class => 'quick-access-preview',
      :data => {'quick-access-preview-target' => 'preview', :state => 'idle'},
      :aria => {:live => 'polite'}
    )

    content_tag(
      :li,
      safe_join([link, preview]),
      :class => 'quick-access-menu',
      :data => {
        :controller => 'quick-access-preview',
        'quick-access-preview-url-value' => preview_quick_access_items_path,
        'quick-access-preview-loading-text-value' => l(:label_loading),
        'quick-access-preview-error-text-value' => l(:label_quick_access_load_error)
      }
    )
  end
end
