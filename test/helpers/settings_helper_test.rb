# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../test_helper'

class SettingsHelperTest < Redmine::HelperTest
  include SettingsHelper
  include ERB::Util

  def test_date_format_setting_options_should_include_human_readable_format
    Date.stubs(:today).returns(Date.parse("2015-07-14"))

    options = date_format_setting_options('en')
    assert_include ["2015-07-14 (yyyy-mm-dd)", "%Y-%m-%d"], options
  end

  def test_timestamp_format_setting_options_should_include_human_readable_format
    sample_time = Time.now.ago(3.days)

    options = timestamp_format_setting_options
    assert_include ["3 days (Relative time)", 'relative_time'], options
    assert_include ["3 days (#{format_time(sample_time)}) (Relative time with absolute time)", 'relative_time_with_absolute_time'], options
    assert_include ["#{format_time(sample_time)} (Absolute time)", 'absolute_time'], options
  end
end
