# frozen_string_literal: true

require_relative '../application_system_test_case'

class ListAutofillSystemTest < ApplicationSystemTestCase
  def setup
    super
    log_user('jsmith', 'jsmith')
  end

  def test_autofill_textile_unordered_list
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Subject', :with => 'Test list autofill feature'
        find('#issue_description_and_toolbar').click
        find('#issue_description').send_keys('* First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "* First item\n" \
          "* ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_autofill_textile_ordered_list
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Subject', :with => 'Test ordered list autofill'
        find('#issue_description_and_toolbar').click
        find('#issue_description').send_keys('# First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "# First item\n" \
          "# ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_remove_list_marker_for_empty_item
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Subject', :with => 'Test empty list item removal'
        find('#issue_description_and_toolbar').click
        find('#issue_description').send_keys('* First item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:enter)  # Press Enter on empty line removes the marker

        assert_equal(
          "* First item\n",
          find('#issue_description').value
        )
      end
    end
  end

  def test_autofill_with_markdown_format
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Subject', :with => 'Test markdown list autofill'
        find('#issue_description_and_toolbar').click
        find('#issue_description').send_keys('- First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "- First item\n" \
          "- ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_autofill_with_markdown_numbered_list
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Subject', :with => 'Test markdown numbered list autofill'
        find('#issue_description_and_toolbar').click
        find('#issue_description').send_keys('1. First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "1. First item\n" \
          "2. ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_list_autofill_disabled_when_text_formatting_blank
    with_settings :text_formatting => '' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Subject', :with => 'Test list autofill disabled'
        find('#issue_description_and_toolbar').click
        find('#issue_description').send_keys('* First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "* First item\n",
          find('#issue_description').value
        )
      end
    end
  end

  def test_textile_nested_list_autofill
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('* Parent item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:backspace, :backspace)  # Remove auto-filled marker
        find('#issue_description').send_keys('** Child item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:backspace, :backspace, :backspace)  # Remove auto-filled marker
        find('#issue_description').send_keys("*** Grandchild item")
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "* Parent item\n" \
          "** Child item\n" \
          "*** Grandchild item\n" \
          "*** ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_common_mark_nested_list_autofill
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Subject', :with => 'Test nested list autofill in Markdown'
        find('#issue_description_and_toolbar').click

        find('#issue_description').send_keys('- Parent item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:backspace, :backspace)  # Remove auto-filled marker
        find('#issue_description').send_keys('  - Child item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "- Parent item\n" \
          "  - Child item\n" \
          "  - ",
          find('#issue_description').value
        )

        find('#issue_description').send_keys(:backspace, :backspace, :backspace, :backspace)  # Remove auto-filled marker
        find('#issue_description').send_keys('    - Grandchild item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "- Parent item\n" \
          "  - Child item\n" \
          "    - Grandchild item\n" \
          "    - ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_common_mark_mixed_list_types
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Subject', :with => 'Test mixed list types in Markdown'
        find('#issue_description_and_toolbar').click

        find('#issue_description').send_keys('1. First numbered item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:backspace, :backspace, :backspace)  # Remove auto-filled numbered list marker
        find('#issue_description').send_keys('   - Nested bullet item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "1. First numbered item\n" \
          "   - Nested bullet item\n" \
          "   - ",
          find('#issue_description').value
        )

        find('#issue_description').send_keys(:backspace, :backspace, :backspace, :backspace, :backspace)  # Remove auto-filled numbered list marker
        find('#issue_description').send_keys('2. Second numbered item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "1. First numbered item\n" \
          "   - Nested bullet item\n" \
          "2. Second numbered item\n" \
          "3. ",
          find('#issue_description').value
        )
      end
    end
  end
end
