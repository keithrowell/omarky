# Fixture dates are +10:00; pin the zone so formatted times match everywhere.
ENV["TZ"] = "Australia/Brisbane"
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "omarky_reader"
require "fixture_repo"   # the library's sample history (test/ruby)
