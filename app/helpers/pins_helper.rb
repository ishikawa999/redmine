# frozen_string_literal: true

module PinsHelper
  def pin_link(pinnable)
    return ''.html_safe unless User.current.logged?

    pin = User.current.pins.find_by(pinnable: pinnable)
    if pin
      link_to sprite_icon('bookmark-delete', l(:button_unpin)), pins_path(
        pinnable_type: pinnable.class.base_class.name, pinnable_id: pinnable.id
      ),
              remote: true, method: :delete, class: 'icon icon-bookmark pin-toggle'
    else
      link_to sprite_icon('bookmark-add', l(:button_pin)), pins_path(
        pinnable_type: pinnable.class.base_class.name, pinnable_id: pinnable.id
      ), remote: true, method: :post, class: 'icon icon-bookmark-off pin-toggle'
    end
  end

  def pin_path_for(pinnable)
    case pinnable
    when Issue
      issue_path(pinnable)
    when WikiPage
      project_wiki_page_path(pinnable.project, pinnable.title)
    when Version
      version_path(pinnable)
    end
  end

  def pin_label(pinnable)
    case pinnable
    when Issue
      "##{pinnable.id} #{pinnable.subject}"
    when WikiPage
      pinnable.pretty_title
    when Version
      pinnable.name
    end
  end

  def pin_type_label(pinnable)
    case pinnable
    when Issue
      l(:label_issue)
    when WikiPage
      l(:label_wiki_page)
    when Version
      l(:label_version)
    end
  end

  def pin_project(pinnable)
    pinnable.project
  end

  def pin_target_link(pinnable)
    link_to pin_label(pinnable), pin_path_for(pinnable)
  end
end
