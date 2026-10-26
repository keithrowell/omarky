require_relative "test_helper"
require "stringio"

# Omarky::Rewrite against a fake claude that replays a scripted stream.
class RewriteTest < Minitest::Test
  DOC = "# Title\n\nThe utilisation of this methodology facilitates improvements.\n\nLast.\n"

  def setup
    @dir = Dir.mktmpdir
    @config = File.join(@dir, "config")
    FileUtils.mkdir_p(@config)
    @args = File.join(@dir, "args.json")
  end

  def teardown = FileUtils.rm_rf(@dir)

  # A claude that records its argv and prints REPLIES[n] for its n-th run
  # as text deltas and a result line.
  def fake(replies, error: nil)
    count = File.join(@dir, "count")
    path = File.join(@dir, "claude")
    File.write(path, <<~RUBY)
      #!/usr/bin/ruby
      require "json"
      n = File.exist?(#{count.inspect}) ? File.read(#{count.inspect}).to_i : 0
      File.write(#{count.inspect}, (n + 1).to_s)
      File.write(#{@args.inspect} + n.to_s, JSON.generate(ARGV))
      puts JSON.generate({ type: "system", subtype: "init" })
      #{error ? "puts JSON.generate({ type: 'result', is_error: true, result: #{error.inspect} }); exit 1" : ""}
      text = #{replies.inspect}[n]
      text.scan(/.{1,7}/m).each { |c| puts JSON.generate({ type: "stream_event", event: { type: "content_block_delta", delta: { type: "text_delta", text: c } } }) }
      puts JSON.generate({ type: "result", subtype: "success", is_error: false, result: text, total_cost_usd: 0.01 })
    RUBY
    File.chmod(0o755, path)
    path
  end

  def job(extra = {})
    a = DOC.index("The utilisation")
    { "path" => "/x/essay.md", "document" => DOC, "start" => a, "end" => DOC.index("\n", a),
      "instruction" => "plainer", "turns" => [] }.merge(extra)
  end

  def run_job(claude, j = job)
    out = StringIO.new
    status = Omarky::Rewrite.new(j, out: out, env: {}, config_dir: @config, claude: claude).run
    [status, out.string.lines.map { JSON.parse(_1) }]
  end

  def test_streams_pieces_then_done
    status, lines = run_job(fake(["This method helps."]))
    assert_equal 0, status
    assert_equal "This method helps.", lines.select { _1["type"] == "text" }.map { _1["text"] }.join
    assert_equal({ "type" => "done", "text" => "This method helps.", "notes" => [], "cost" => 0.01 }, lines.last)
  end

  def test_prompt_marks_the_selection_and_runs_without_tools
    run_job(fake(["x"]))
    argv = JSON.parse(File.read("#{@args}0"))
    prompt = argv.last
    assert_includes prompt, "<selection>The utilisation of this methodology facilitates improvements.</selection>"
    assert_includes prompt, %(<document name="essay.md">)
    assert_includes prompt, "<instruction>plainer</instruction>"
    assert_equal "", argv[argv.index("--tools") + 1]
    assert_includes argv, "--no-session-persistence"
  end

  def test_earlier_turns_go_with_a_refinement
    run_job(fake(["x"]), job("turns" => [{ "instruction" => "plainer", "rewrite" => "This helps." }], "instruction" => "warmer"))
    prompt = JSON.parse(File.read("#{@args}0")).last
    assert_includes prompt, "<rewrite>This helps.</rewrite>"
    assert_includes prompt, "Start from the last rewrite"
  end

  def test_style_guide_joins_the_system_prompt
    File.write(File.join(@config, "writing.md"), "Never use the word utilise.")
    run_job(fake(["x"]))
    argv = JSON.parse(File.read("#{@args}0"))
    assert_includes argv[argv.index("--system-prompt") + 1], "Never use the word utilise."
  end

  def test_a_fenced_reply_is_unwrapped_and_spacing_follows_the_selection
    j = job("start" => DOC.index("The utilisation") - 1)
    _, lines = run_job(fake(["```markdown\nThis helps.\n```"]), j)
    assert_equal "\nThis helps.", lines.last["text"]
  end

  def test_checker_complaints_go_back_once
    check = File.join(@config, "check")
    File.write(check, "#!/bin/sh\ngrep -q robust \"$1\" && { echo '  [fix] banned word robust | L1: x'; exit 1; }\nexit 0\n")
    File.chmod(0o755, check)
    _, lines = run_job(fake(["A robust method.", "A sound method."]))
    types = lines.map { _1["type"] }
    assert_equal %w[checking retry done], types - ["text"]
    assert_equal ["banned word robust"], lines.find { _1["type"] == "retry" }["notes"]
    assert_equal "A sound method.", lines.last["text"]
    assert_includes JSON.parse(File.read("#{@args}1")).last, "banned word robust"
  end

  def test_claude_error_is_reported
    status, lines = run_job(fake([], error: "Usage limit reached"))
    assert_equal 1, status
    assert_equal({ "type" => "error", "message" => "Usage limit reached" }, lines.last)
  end

  def test_no_claude
    status, lines = run_job(nil)
    assert_equal 1, status
    assert_match(/not installed/, lines.last["message"])
  end
end
