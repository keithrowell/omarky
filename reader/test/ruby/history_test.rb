require_relative "test_helper"

class HistoryTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @path = FixtureRepo.build(@dir)
    @h = OmaRead::History.new(@path)
  end

  def teardown = FileUtils.rm_rf(@dir)

  def test_versions_newest_first
    v = @h.versions
    assert_equal 6, v.size
    assert_equal "Use the client's name", v.first.subject
    assert_equal "Danny Malone", v[1].author
    assert_equal "Twelve weeks reads as long.", v[1].body
    assert_equal Time.parse("2026-10-23T16:12:00+10:00"), v[1].time
  end

  def test_text_at
    assert_equal "v5\n\nApproach two.\n", @h.text_at(@h.versions[1].sha)
  end

  def test_outside_a_repo
    Dir.mktmpdir do |d|
      f = File.join(d, "x.md"); File.write(f, "x")
      refute OmaRead::History.new(f).in_repo?
    end
  end
end
