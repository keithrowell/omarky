require_relative "test_helper"

class ResolverTest < Minitest::Test
  NOW = Time.parse("2026-10-25T10:00:00+10:00")   # a Sunday

  def setup
    @dir = Dir.mktmpdir
    @path = FixtureRepo.build(@dir)
    @h = Omarky::History.new(@path)
    @r = Omarky::Resolver.new(@h, now: NOW)
  end

  def teardown = FileUtils.rm_rf(@dir)

  def subject_of(spec, **kw) = @r.resolve(spec, **kw).subject

  def test_person
    assert_equal "Tighten the approach section", subject_of("danny")
    assert_equal "Tighten the approach section", subject_of("Danny Malone")
    assert_equal "Use the client's name", subject_of("keith")
    assert_equal "Use the client's name", subject_of("me")
  end

  def test_days
    assert_equal "Use the client's name", subject_of("yesterday")              # end of 24 Oct
    assert_equal "Team section", subject_of("thu")                             # most recent Thursday before today: 22 Oct
    assert_equal "First pass at the approach", subject_of("a week ago")        # end of 18 Oct: last check-in is 17 Oct
    assert_equal "First pass at the approach", subject_of("17 oct")
    assert_equal "First pass at the approach", subject_of("2026-10-17")
    assert_equal "Use the client's name", subject_of("today")
    assert_equal "Tighten the approach section", subject_of("2 days ago")      # end of 23 Oct
  end

  def test_person_and_day
    assert_equal "Tighten the approach section", subject_of("danny fri")       # Fri 23 Oct: Danny checked in that afternoon
    assert_equal "First pass at the approach", subject_of("danny 17 oct")
    assert_equal "Team section", subject_of("keith 20 oct")
  end

  def test_sent_reads_sent_md
    assert_equal Date.new(2026, 10, 21), @r.sent_date
    assert_equal "Team section", subject_of("sent")
  end

  def test_before
    assert_equal "Team section", subject_of("before danny")
  end

  def test_now_and_refs
    assert_equal :now, @r.resolve("now")
    assert_equal "Team section", subject_of("HEAD~2")
    assert_equal "Team section", subject_of(@h.versions[2].sha[0, 8])
  end

  def test_before_bound
    danny = @r.resolve("danny")
    assert_equal "Team section", subject_of("keith", before: danny)
    assert_equal "First pass at the approach", subject_of("before keith", before: danny)   # Keith's last inside the bound, then one back
    assert_equal "Team section", subject_of("before danny", before: danny)                # the bound itself: the one before it
    e = assert_raises(Omarky::Unresolved) { @r.resolve("before 7 oct", before: danny) }
    assert_equal "There is nothing before Keith, Wed 7 Oct, 6:20 pm.", e.message
  end

  def test_unresolved_messages
    e = assert_raises(Omarky::Unresolved) { @r.resolve("salman") }
    assert_equal "Salman has no check-ins of this file.", e.message
    e = assert_raises(Omarky::Unresolved) { @r.resolve("3 oct") }
    assert_equal "The file did not exist yet on 3 October.", e.message
  end

  def test_default_from
    assert_equal "Tighten the approach section", @r.default_from("v6\n\nApproach three.\n").subject
    assert_equal "Use the client's name", @r.default_from("edited on disk").subject
  end

  # "before now" is default_from against the file on disk: HEAD when the
  # disk has edits, otherwise the check-in before HEAD.
  def test_before_now
    assert_equal "Tighten the approach section", subject_of("before now")
    File.write(@path, "edited on disk\n")
    assert_equal "Use the client's name", subject_of("before now")
    assert_equal "Team section", subject_of("before now", before: @r.resolve("danny"))
  end

  def test_before_now_with_one_version
    Dir.mktmpdir do |d|
      f = File.join(d, "one.md")
      FixtureRepo.run(d, "git", "init", "-q", "-b", "main")
      File.write(f, "only\n")
      FixtureRepo.run(d, "git", "add", ".")
      env = { "GIT_AUTHOR_NAME" => "Keith Rowell", "GIT_AUTHOR_EMAIL" => "keith@example.com",
              "GIT_COMMITTER_NAME" => "Keith Rowell", "GIT_COMMITTER_EMAIL" => "keith@example.com" }
      FixtureRepo.run(d, env, "git", "commit", "-q", "-m", "Only")
      r = Omarky::Resolver.new(Omarky::History.new(f), now: NOW)
      e = assert_raises(Omarky::Unresolved) { r.resolve("before now") }
      assert_equal "There is nothing before now.", e.message
    end
  end

  def test_shortcuts_and_display
    labels = @r.shortcuts.map { _1["label"] }
    assert_equal ["Danny's last edit", "my last edit", "yesterday", "a week ago", "when it was sent"], labels
    d = @r.display(@r.resolve("danny"))
    assert_equal "Danny", d["who"]
    assert_equal "Fri 23 Oct, 4:12 pm", d["when"]
    assert_equal "Friday 23 October 2026, 4:12 pm", d["long"]
  end
end

# A first name matches a one-word git handle and the email's local part.
class ResolverHandleTest < Minitest::Test
  FakeHistory = Struct.new(:versions, :user_name, :path, :root) do
    def in_repo? = true
  end

  def setup
    t = Time.parse("2026-10-20T10:00:00+10:00")
    @versions = [
      Omarky::Version.new("b" * 40, "Keith Rowell", "keith@example.com", t + 86_400, "Later", ""),
      Omarky::Version.new("a" * 40, "dannymalonerace", "danny.malone@example.com", t, "Danny's handle", ""),
    ]
    @r = Omarky::Resolver.new(FakeHistory.new(@versions, "Keith Rowell", "/tmp/none/x.md", "/tmp/none"), now: t + 172_800)
  end

  def test_handle_matches_first_name
    assert_equal "Danny's handle", @r.resolve("danny").subject
    assert_equal "Danny's handle", @r.resolve("Danny").subject
  end

  def test_short_prefix_does_not_match
    assert_raises(Omarky::Unresolved) { @r.resolve("da") }
  end

  def test_handle_displays_as_the_email_name
    assert_equal "Danny", @r.display(@r.resolve("danny"))["who"]
    assert_equal "Danny's last edit", @r.shortcuts.first["label"]
  end
end
