require_relative "test_helper"
require "open3"

# bin/omaread end to end. The window process is a fake `qs` on PATH that
# records its arguments and the environment it was started with.
class CliTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  BIN = File.join(ROOT, "bin/omaread")
  FAKE_QS = <<~'SH'
    #!/bin/sh
    out="${FAKE_QS_OUT:-/dev/stdout}"
    {
      printf 'argv:'; for a in "$@"; do printf ' [%s]' "$a"; done; printf '\n'
      printf 'open<<%s>>\n' "$OMAREAD_OPEN"
      printf 'data<<%s>>\n' "$XDG_DATA_DIRS"
    } >>"$out"
  SH

  def setup
    @dir = Dir.mktmpdir
    @path = FixtureRepo.build(@dir)
    @bin = File.join(@dir, "fakebin")
    FileUtils.mkdir_p(@bin)
    File.write(File.join(@bin, "qs"), FAKE_QS)
    File.chmod(0o755, File.join(@bin, "qs"))
    @runtime = File.join(@dir, "runtime")
    @state = File.join(@dir, "state")
  end

  def teardown = FileUtils.rm_rf(@dir)

  # NOW is Sunday 25 Oct 2026, 10:00 +10:00. The fake qs is first on PATH,
  # the lock lives under a private runtime dir and the log under a private
  # state dir, so a real OmaRead on this machine is never touched.
  def env(extra = {})
    { "OMAREAD_NOW" => "2026-10-25T10:00:00+10:00", "PATH" => "#{@bin}:#{ENV['PATH']}",
      "XDG_RUNTIME_DIR" => @runtime, "OMAREAD_INSTANCE" => "test", "OMAREAD_STATE_DIR" => @state,
      "XDG_DATA_DIRS" => "/usr/share" }.merge(extra)
  end

  def run_cli(*args, env: {})
    Open3.capture3(env(env), BIN, *args)
  end

  # The target lines the fake qs saw in OMAREAD_OPEN.
  def opened(out) = out[/^open<<(.*?)>>\n/m, 1]

  # --- reading --------------------------------------------------------------

  def test_help_prints_the_header_comment
    out, _, st = run_cli("--help")
    assert st.success?
    assert_match(/\AOmaRead: a Markdown reader for Omarchy\.\n\n  omaread \[FILE\.md\[#anchor\] …\]/, out)
    assert_includes out, "omaread FILE --changes"
    refute_match(/LOAD_PATH|^#!/, out)
    assert_equal out, run_cli("x.md", "-h").first
  end

  def test_build_prints_the_import_path
    out, _, st = run_cli("--build")
    assert_equal 0, st.exitstatus
    assert_equal File.join(ROOT, "build/qml"), out.strip
  end

  def test_version
    out, _, st = run_cli("-V")
    assert st.success?
    assert_equal "omaread #{File.read(File.join(ROOT, 'VERSION')).strip}\n", out
  end

  def test_foreground_opens_each_file_in_order
    other = File.join(@dir, "other.md"); File.write(other, "# Other\n")
    out, _, st = run_cli("--foreground", @path, "#{other}#intro", env: { "HOME" => @dir })
    assert st.success?, out
    assert_includes out, "argv: [--log-rules] [qt.qml.usedbeforedeclared=false;qt.qpa.services.warning=false] [-p] [#{ROOT}/ui/shell.qml]\n"
    assert_equal "#{@path}\n#{other}#intro", opened(out)
    assert_includes out, "data<<#{@dir}/.local/share/omaread/ksh:/usr/share>>\n"
  end

  def test_no_args_opens_an_empty_window
    out, _, st = run_cli("--foreground")
    assert st.success?
    assert_equal "", opened(out)
  end

  def test_relative_paths_file_urls_and_missing_files
    out, _, _ = Open3.capture3(env, BIN, "--foreground", "notes.md", "file://#{@path}", "missing.md#top", chdir: @dir)
    assert_equal "#{@dir}/notes.md\n#{@path}\n#{@dir}/missing.md#top", opened(out)
  end

  def test_a_hash_in_a_real_file_name_is_not_an_anchor
    hashed = File.join(@dir, "c#.md"); File.write(hashed, "# C#\n")
    out, _, _ = run_cli("--foreground", hashed, "#{hashed}#types")
    assert_equal "#{hashed}\n#{hashed}#types", opened(out)
  end

  def test_detached_start_logs_to_the_state_dir
    _, _, st = run_cli(@path)
    assert st.success?
    log = File.join(@state, "qs.log")
    20.times { break if File.file?(log) && File.read(log).include?("data<<"); sleep 0.1 }
    text = File.read(log)
    assert_includes text, "[-p] [#{ROOT}/ui/shell.qml]"
    assert_equal @path, opened(text)
  end

  def test_running_instance_gets_the_targets_over_ipc
    FileUtils.mkdir_p(File.join(@runtime, "omaread"))
    lock = File.join(@runtime, "omaread", "test.lock")
    File.write(lock, "#{Process.pid}\n")
    record = File.join(@dir, "ipc.txt")
    File.open(lock) do |held|
      assert held.flock(File::LOCK_EX | File::LOCK_NB)
      _, _, st = run_cli(@path, "#{@path}#team", env: { "FAKE_QS_OUT" => record })
      assert st.success?
      calls = File.read(record).lines.grep(/^argv:/)
      assert_equal ["argv: [ipc] [--pid] [#{Process.pid}] [call] [omaread] [open] [#{@path}]\n",
                    "argv: [ipc] [--pid] [#{Process.pid}] [call] [omaread] [open] [#{@path}#team]\n"], calls
      refute File.exist?(File.join(@state, "qs.log")), "must not start a second qs"
      File.delete(record)
      _, _, st = run_cli(env: { "FAKE_QS_OUT" => record })
      assert st.success?
      assert_equal "argv: [ipc] [--pid] [#{Process.pid}] [call] [omaread] [open] []\n", File.read(record).lines.first
    end
  end

  def test_stale_lock_starts_a_new_instance
    FileUtils.mkdir_p(File.join(@runtime, "omaread"))
    File.write(File.join(@runtime, "omaread", "test.lock"), "#{Process.pid}\n")   # alive, but nobody holds the lock
    out, _, st = run_cli("--foreground", @path)
    assert st.success?
    assert_includes out, "[-p] [#{ROOT}/ui/shell.qml]"
    assert_equal @path, opened(out)
  end

  # --- changes --------------------------------------------------------------

  def test_changes_sends_before_now
    out, _, st = run_cli("--foreground", @path, "--changes")
    assert st.success?
    assert_equal "#{@path}\tbefore now\t", opened(out)
  end

  def test_from_and_to_are_sent_raw
    out, _, _ = run_cli("--foreground", "--from", "danny", "--to", "keith fri", @path)
    assert_equal "#{@path}\tdanny\tkeith fri", opened(out)
    out, _, _ = run_cli("--foreground", @path, "--from", "HEAD~2")
    assert_equal "#{@path}\tHEAD~2\t", opened(out)
    out, _, _ = run_cli("--foreground", "#{@path}#team", "--to", "danny")
    assert_equal "#{@path}#team\tbefore danny\tdanny", opened(out)
  end

  def test_changes_over_ipc
    FileUtils.mkdir_p(File.join(@runtime, "omaread"))
    lock = File.join(@runtime, "omaread", "test.lock")
    File.write(lock, "#{Process.pid}\n")
    record = File.join(@dir, "ipc.txt")
    File.open(lock) do |held|
      held.flock(File::LOCK_EX | File::LOCK_NB)
      _, _, st = run_cli(@path, "--from", "danny", env: { "FAKE_QS_OUT" => record })
      assert st.success?
      assert_equal "argv: [ipc] [--pid] [#{Process.pid}] [call] [omaread] [open] [#{@path}\tdanny\t]\n", File.read(record).lines.first
    end
  end

  def test_changes_flags_need_one_existing_file
    _, err, st = run_cli("--changes")
    assert_equal 2, st.exitstatus
    assert_equal "omaread: --changes needs one FILE\n", err
    _, err, st = run_cli("--from", "danny", @path, File.join(@dir, "SENT.md"))
    assert_equal 2, st.exitstatus
    assert_equal "omaread: --from needs one FILE\n", err
    _, err, st = run_cli("missing.md", "--changes")
    assert_equal 2, st.exitstatus
    assert_equal "omaread: missing.md: no such file\n", err
    _, err, st = run_cli(@path, "--from")
    assert_equal 2, st.exitstatus
    assert_equal "omaread: --from needs a SPEC\n", err
  end

  def test_outside_a_repo
    Dir.mktmpdir do |d|
      f = File.join(d, "x.md"); File.write(f, "x\n")
      %w[--changes --list].each do |flag|
        _, err, st = run_cli(f, flag)
        assert_equal 2, st.exitstatus, flag
        assert_equal "omaread: #{f} is not in a git repository\n", err
      end
      _, err, st = Open3.capture3(env, BIN, "x.md", "--from", "danny", chdir: d)
      assert_equal 2, st.exitstatus
      assert_equal "omaread: x.md is not in a git repository\n", err
      out, _, st = run_cli("--foreground", f, "--to", "now")      # "now" is fine anywhere
      assert st.success?
      assert_equal "#{f}\tbefore now\tnow", opened(out)
      out, _, st = run_cli(f, "--versions")
      assert st.success?
      assert_equal({ "inRepo" => false, "dirty" => false, "history" => [], "shortcuts" => [] }, JSON.parse(out))
      _, err, st = run_cli(f, "--resolve", "danny")
      assert_equal 2, st.exitstatus
      assert_match(/not in a git repository/, err)
    end
  end

  def test_list
    out, _, st = run_cli(@path, "--list")
    assert st.success?
    lines = out.lines
    assert_equal 6, lines.size
    assert_equal "Keith\tSat 24 Oct, 5:02 pm\tUse the client's name\n", lines.first
    assert_equal "Keith\tWed 7 Oct, 6:20 pm\tStart the proposal\n", lines.last
  end

  def test_resolve
    out, _, st = run_cli(@path, "--resolve", "danny")
    assert st.success?
    j = JSON.parse(out)
    assert_equal %w[who name sha when long iso subject body label text].sort, j.keys.sort
    assert_equal "Danny", j["who"]
    assert_equal "Danny", j["label"]
    assert_equal "Danny Malone", j["name"]
    assert_equal "Fri 23 Oct, 4:12 pm", j["when"]
    assert_equal "Tighten the approach section", j["subject"]
    assert_equal "Twelve weeks reads as long.", j["body"]
    assert_equal "v5\n\nApproach two.\n", j["text"]
  end

  def test_resolve_now
    out, _, st = run_cli(@path, "--resolve", "now")
    assert st.success?
    assert_equal({ "label" => "Now", "who" => "Now", "text" => File.read(@path) }, JSON.parse(out))
  end

  def test_resolve_before_now
    out, _, st = run_cli(@path, "--resolve", "before now")
    assert st.success?
    assert_equal "Tighten the approach section", JSON.parse(out)["subject"]   # HEAD equals disk, so the one before
    File.write(@path, "edited on disk\n")
    out, _, _ = run_cli(@path, "--resolve", "before now")
    assert_equal "Use the client's name", JSON.parse(out)["subject"]
  end

  def test_resolve_bounded_by_to
    out, _, st = run_cli(@path, "--resolve", "keith", "--to", "danny")
    assert st.success?
    assert_equal "Team section", JSON.parse(out)["subject"]
    out, _, _ = run_cli(@path, "--resolve", "before danny fri", "--to", "danny fri")
    assert_equal "Team section", JSON.parse(out)["subject"]
  end

  def test_resolve_unresolved
    out, err, st = run_cli(@path, "--resolve", "salman")
    assert_equal 1, st.exitstatus
    assert_equal "", out
    assert_equal "Salman has no check-ins of this file.\n", err
  end

  def test_versions
    out, _, st = run_cli(@path, "--versions")
    assert st.success?
    j = JSON.parse(out)
    assert_equal %w[inRepo dirty history shortcuts me], j.keys
    assert_equal true, j["inRepo"]
    assert_equal false, j["dirty"]
    assert_equal "Keith Rowell", j["me"]
    assert_equal 6, j["history"].size
    assert_equal %w[who name sha when long iso subject body].sort, j["history"].first.keys.sort
    assert_equal "Use the client's name", j["history"].first["subject"]
    assert_equal "Start the proposal", j["history"].last["subject"]
    assert_equal ["Danny's last edit", "my last edit", "yesterday", "a week ago", "when it was sent"], j["shortcuts"].map { _1["label"] }
    assert_equal "danny", j["shortcuts"].first["spec"]
  end

  def test_versions_dirty_when_the_disk_differs
    File.write(@path, "edited on disk\n")
    j = JSON.parse(run_cli(@path, "--versions").first)
    assert_equal true, j["dirty"]
    assert_equal 6, j["history"].size
  end

  # --- run as omachanges ----------------------------------------------------

  def test_as_omachanges_a_bare_file_opens_its_changes
    link = File.join(@bin, "omachanges")
    File.symlink(BIN, link)
    out, _, st = Open3.capture3(env, link, "--foreground", @path)
    assert st.success?
    assert_equal "#{@path}\tbefore now\t", opened(out)
    out, _, _ = Open3.capture3(env, link, "--foreground", @path, "--from", "danny")
    assert_equal "#{@path}\tdanny\t", opened(out)
    out, _, _ = Open3.capture3(env, link, "--foreground", @path, "--to", "danny")
    assert_equal "#{@path}\tbefore danny\tdanny", opened(out)
    _, err, st = Open3.capture3(env, link)
    assert_equal 2, st.exitstatus
    assert_equal "omaread: omachanges needs one FILE\n", err
    out, _, _ = Open3.capture3(env, link, @path, "--list")
    assert_equal 6, out.lines.size
  end
end
