# frozen_string_literal: true

require_relative '../application_system_test_case'

class ListIndentSystemTest < ApplicationSystemTestCase
  def setup
    super
    log_user('jsmith', 'jsmith')
  end

  # Tab: inserts 2 spaces for bullet lists, 4 spaces for ordered lists
  def test_tab_indents_common_mark_bullet_list
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Description', with: "- item"
        find('#issue_description').send_keys(:tab)

        assert_equal "  - item", find('#issue_description').value
      end
    end
  end

  def test_tab_indents_common_mark_ordered_list
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Description', with: "1. item"
        find('#issue_description').send_keys(:tab)

        assert_equal "    1. item", find('#issue_description').value
      end
    end
  end

  # Shift+Tab: removes indentation
  def test_shift_tab_unindents_common_mark_bullet_list
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        set_textarea_value 'issue_description', "- parent\n  - child"
        find('#issue_description').send_keys([:shift, :tab])

        assert_equal "- parent\n- child", find('#issue_description').value
      end
    end
  end

  def test_shift_tab_removes_partial_indent_on_common_mark_list
    # Removes only as many spaces as exist when indent is less than the step size
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        set_textarea_value 'issue_description', "- parent\n - child"
        find('#issue_description').send_keys([:shift, :tab])

        assert_equal "- parent\n- child", find('#issue_description').value
      end
    end
  end

  def test_shift_tab_does_nothing_on_common_mark_list_with_no_indent
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Description', with: "- item"
        find('#issue_description').send_keys([:shift, :tab])

        assert_equal "- item", find('#issue_description').value
      end
    end
  end

  private

  # Use execute_script to set multi-line values directly via JS,
  # since fill_in sends keystrokes which trigger the list autofill handler.
  def set_textarea_value(id, text)
    page.execute_script(
      "const el = document.getElementById(arguments[0]);" \
      "el.value = arguments[1];" \
      "el.setSelectionRange(el.value.length, el.value.length);",
      id,
      text
    )
  end
end
