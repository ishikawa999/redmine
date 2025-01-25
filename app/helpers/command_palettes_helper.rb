module CommandPalettesHelper

  SHORTCUT_KEYS = {
    mac: {
      chrome_edge: {
        new_issue: "Ctrl + Opt + 7",
        toggle_edit_preview: "⌘ + Shift + P",
        submit_form: "⌘ + Enter",
        edit_page: "Ctrl + Opt + e",
        search_box: "Ctrl + Opt + f",
        search_page: "Ctrl + Opt + 4",
        next_navigation: "Ctrl + Opt + n",
        previous_navigation: "Ctrl + Opt + p"
      },
      firefox: {
        new_issue: "Ctrl + Opt + 7",
        toggle_edit_preview: nil,
        submit_form: "⌘ + Enter",
        edit_page: nil,
        search_box: "Ctrl + Opt + f",
        search_page: "Ctrl + Opt + 4",
        next_navigation: nil,
        previous_navigation: nil
      }
    },
    windows: {
      chrome_edge: {
        new_issue: "Alt + 7",
        toggle_edit_preview: "Ctrl + Shift + P",
        submit_form: "Ctrl + Enter",
        edit_page: "Alt + Shift + e",
        search_box: "Alt + Shift + f",
        search_page: "Alt + 4",
        next_navigation: "Alt + n",
        previous_navigation: "Alt + p"
      },
      firefox: {
        new_issue: "Alt + Shift + 7",
        toggle_edit_preview: nil,
        submit_form: "Ctrl + Enter",
        edit_page: "Alt + Shift + e",
        search_box: "Alt + Shift + f",
        search_page: "Alt + Shift + 4",
        next_navigation: "Alt + Shift + n",
        previous_navigation: "Alt + Shift + p"
      }
    }
  }.freeze

  def setup_command_palette(project, issue)
    #command_palette = CommandPalette.new(search_word: nil, project: project, issue: issue, controller_name: controller_name, action_name: action_name)
    client_info = detect_client_info
    shortcuts = SHORTCUT_KEYS.dig(client_info[:os], client_info[:browser]) || {}
    commands = commands(project, issue, shortcuts)

    content_tag(:div, id: 'commandPalette', class: 'command-palette') do
      # 入力フィールド
      input_field = tag.input(type: 'text', id: 'commandInput', placeholder: 'Type a command...', autocomplete: 'off')

      # コマンドリスト
      command_list = content_tag(:ul, id: 'commandList') do
        safe_join(
          commands.map do |command|
            content_tag(:li, { data: { command_type: :default } }) do
              if command[:link].present?
                command[:link] + (command[:shortcut] ? tag.span(command[:shortcut], class: 'shortcut-info') : '')
              else
                link_to(
                  sprite_icon("command-palette-#{command[:type]}", command[:label]),
                  command[:url],
                ) +
                (command[:shortcut] ? tag.span(command[:shortcut], class: 'shortcut-info') : '')
              end
            end
          end
        )
      end

      # 入力フィールドとコマンドリストを結合
      input_field + command_list
    end
  end


  def commands(project, issue, shortcuts)
    commands = []
    commands += issue_commands(issue, shortcuts) if issue&.persisted?
    commands += project_commands(project, shortcuts) if project&.persisted?
    commands += global_commands(project, shortcuts)
    commands
  end

  def global_commands(project, shortcuts)
    commands = []

    commands << { type: :redirect, label: l(:label_my_page), url: my_page_path }
    commands << { type: :redirect, label: l(:label_project_all), url: projects_path }
    commands << { type: :redirect, label: l(:label_search), url: search_path(project_id: project&.id), shortcut: shortcuts[:search_page] }
    Project.where(id: User.current.bookmarked_project_ids).each do |bookmarked_project|
      next if bookmarked_project == project

      commands << { type: :redirect, label: "#{l(:label_my_bookmarks)}: #{bookmarked_project.name}", url: project_path(bookmarked_project) }
    end
    commands
  end

  def project_commands(project, shortcuts)
    # あとで権限も考慮する
    commands = []
    return [] if project.nil?

    project.enabled_module_names.each do |enabled_module_name|
      case enabled_module_name
      when 'issue_tracking'
        commands << { type: :redirect, label: l(:label_issue_new), url: new_issue_path(project_id: project.id), shortcut: shortcuts[:new_issue] }
        commands << { type: :redirect, label: l(:project_module_issue_tracking), url: issues_path(project_id: project.id) }
      when 'time_tracking'
        commands << { type: :redirect, label: l(:button_log_time), url: new_project_time_entry_path(project_id: project.id) }
        commands << { type: :redirect, label: l(:project_module_time_tracking), url: time_entries_path(project_id: project.id) }
      when 'news'
        commands << { type: :redirect, label: l(:project_module_news), url: project_news_index_path(project_id: project.id) }
      when 'documents'
        commands << { type: :redirect, label: l(:project_module_documents), url: project_documents_path(project_id: project.id) }
      when 'files'
        commands << { type: :redirect, label: l(:project_module_files), url: project_files_path(project_id: project.id) }
      when 'wiki'
        commands << { type: :redirect, label: l(:project_module_wiki), url: project_wiki_index_path(project_id: project.id) }
      when 'repository'
        commands << { type: :redirect, label: l(:project_module_repository), url: project_repositories_path(project_id: project.id) }
      when 'boards'
        commands << { type: :redirect, label: l(:project_module_boards), url: project_boards_path(project_id: project.id) }
      when 'calendar'
        commands << { type: :redirect, label: l(:project_module_calendar), url: project_calendar_path(project_id: project.id) }
      when 'gantt'
        commands << { type: :redirect, label: l(:project_module_gantt), url: project_gantt_path(project_id: project.id) }
      when 'versions'
        commands << { type: :redirect, label: l(:project_module_versions), url: project_versions_path(project_id: project.id) }
      end
    end

    commands
  end

  def issue_commands(issue, shortcuts)
    commands = []
    commands << { link: link_to(sprite_icon('edit', l(:button_edit)), edit_issue_path(issue),
    :onclick => 'showAndScrollTo("update", "issue_notes"); return false;',
    :class => 'icon icon-edit ', :accesskey => accesskey(:edit)), shortcut: shortcuts[:edit_page] } if issue.editable?
    commands << { link: watcher_link(issue, User.current) } if defined?(watcher_link)
    commands << { link: link_to(sprite_icon('copy', l(:button_copy)), project_copy_issue_path(issue.project, issue),
                :class => 'icon icon-copy ') } if User.current.allowed_to?(:copy_issues, issue.project) && Issue.allowed_target_projects.any?
    commands << { link: copy_object_url_link(issue_url(@issue, only_path: false)) }
    commands
  end

  def detect_client_info
    user_agent = request.user_agent

    os =
      if user_agent.include?("Mac")
        :mac
      elsif user_agent.include?("Windows")
        :windows
      else
        :other
      end

    browser =
      if user_agent.include?("Firefox")
        :firefox
      elsif user_agent.include?("Chrome") || user_agent.include?("Edg")
        :chrome_edge
      else
        :other
      end

    { os: os, browser: browser }
  end
end
