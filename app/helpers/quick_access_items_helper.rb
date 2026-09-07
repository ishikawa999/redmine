# frozen_string_literal: true

module QuickAccessItemsHelper
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
      "##{target.id} #{target.subject}"
    when WikiPage
      target.pretty_title
    when Version
      target.name
    end
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
end
