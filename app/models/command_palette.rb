# 検索する機能はいったんなしでパッチを作り込む
# コマンドパレットのショートカットキーがわからなくても良いようにトップメニューにアイコンをおく
# 機能相当のショートカットキーを右に置く
# 固定のリンク系はAPIにするよりもon offの方がいいような...
# ウォッチ機能みたいなAction系も増やしたい

class CommandPalette
  include ActiveModel::Model
  extend ActiveModel::Callbacks
  include ActiveModel::Validations
  include Redmine::I18n
  include Rails.application.routes.url_helpers

  def initialize(search_word:, issue:, project:, controller_name:, action_name:)
    @search_word = search_word&.downcase
    @project = project
    @issue = issue
    @controller_name = controller_name
    @action_name = action_name
  end

  def commands
    commands = []
    commands += project_commands
    commands += global_commands
    commands
  end

  def global_commands
    commands = []

    commands << { type: :redirect, label: l(:label_my_page), url: my_page_path }
    commands << { type: :redirect, label: l(:label_project_all), url: projects_path }
    commands << { type: :redirect, label: l(:label_search), url: search_path } if @project.nil?
    Project.where(id: User.current.bookmarked_project_ids).each do |bookmarked_project|
      next if bookmarked_project == @project

      commands << { type: :redirect, label: "#{l(:label_my_bookmarks)}: #{bookmarked_project.name}", url: project_path(bookmarked_project) }
    end
    commands
  end

  def project_commands
    # あとで権限も考慮する
    commands = []
    return [] if @project.nil?

    @project.enabled_module_names.each do |enabled_module_name|
      case enabled_module_name
      when 'issue_tracking'
        commands << { type: :redirect, label: l(:label_issue_new), url: new_issue_path(project_id: @project.id) }
        commands << { type: :redirect, label: l(:project_module_issue_tracking), url: issues_path(project_id: @project.id) }
      when 'time_tracking'
        commands << { type: :redirect, label: l(:button_log_time), url: new_project_time_entry_path(project_id: @project.id) }
        commands << { type: :redirect, label: l(:project_module_time_tracking), url: time_entries_path(project_id: @project.id) }
      when 'news'
        commands << { type: :redirect, label: l(:project_module_news), url: project_news_index_path(project_id: @project.id) }
      when 'documents'
        commands << { type: :redirect, label: l(:project_module_documents), url: project_documents_path(project_id: @project.id) }
      when 'files'
        commands << { type: :redirect, label: l(:project_module_files), url: project_files_path(project_id: @project.id) }
      when 'wiki'
        commands << { type: :redirect, label: l(:project_module_wiki), url: project_wiki_index_path(project_id: @project.id) }
      when 'repository'
        commands << { type: :redirect, label: l(:project_module_repository), url: project_repositories_path(project_id: @project.id) }
      when 'boards'
        commands << { type: :redirect, label: l(:project_module_boards), url: project_boards_path(project_id: @project.id) }
      when 'calendar'
        commands << { type: :redirect, label: l(:project_module_calendar), url: project_calendar_path(project_id: @project.id) }
      when 'gantt'
        commands << { type: :redirect, label: l(:project_module_gantt), url: project_gantt_path(project_id: @project.id) }
      when 'versions'
        commands << { type: :redirect, label: l(:project_module_versions), url: project_versions_path(project_id: @project.id) }
      end
    end

    commands
  end

  def issue_commands

  end
end
