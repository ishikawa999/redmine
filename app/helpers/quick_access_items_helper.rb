# frozen_string_literal: true

module QuickAccessItemsHelper
  # Renders the account menu, with a submenu of the latest items under quick access
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

  def quick_access_link(target)
    return ''.html_safe unless User.current.logged?

    item = User.current.quick_access_items.find_by(target: target)
    identity = {
      target_type: target.class.base_class.name,
      target_id: target.id
    }
    dom_id = "quick-access-toggle-#{target.class.base_class.name.underscore.dasherize}-#{target.id}"

    if item
      link_to sprite_icon('link-break', l(:button_remove_from_quick_access)), quick_access_items_path(identity),
              remote: true, method: :delete, id: dom_id, class: 'icon icon-link-break quick-access-toggle'
    else
      link_to sprite_icon('link-add', l(:button_add_to_quick_access)), quick_access_items_path(identity),
              remote: true, method: :post, id: dom_id, class: 'icon icon-link-add quick-access-toggle'
    end
  end

  def quick_access_path_for(target)
    case target
    when Issue
      issue_path(target)
    when WikiPage
      project_wiki_page_path(target.project, target.title)
    when Version
      version_path(target)
    end
  end

  def quick_access_label(target)
    case target
    when Issue
      "#{target.tracker} ##{target.id} #{target.subject}"
    when WikiPage
      target.pretty_title
    when Version
      target.name
    end
  end

  def quick_access_status_badge(target)
    issue_status_type_badge(target.status) if target.is_a?(Issue)
  end

  def quick_access_type_label(target)
    case target
    when Issue
      l(:label_issue)
    when WikiPage
      l(:label_wiki_page)
    when Version
      l(:label_version)
    end
  end

  def quick_access_project(target)
    target.project
  end

  def quick_access_target_link(target)
    link_to quick_access_label(target), quick_access_path_for(target)
  end

  private

  def render_quick_access_menu_node(node)
    caption, url, selected = extract_node_details(node)
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
