require "json"
require "open3"
require "tempfile"

module Omarky
  # A rewrite of part of a Markdown document by Claude, for the editor's
  # instruction line (spec 2026-10-26-rewrite-with-claude, decision 0019).
  # The window writes a job file and runs `omarky rewrite --job FILE`; this
  # runs Claude Code headless with no tools and streams JSON lines back:
  #
  #   {"type":"text","text":"…"}        a piece of the rewrite, in order
  #   {"type":"checking"}               the writing checker is reading it
  #   {"type":"retry","notes":[…]}      the checker found problems; the
  #                                     rewrite starts again from empty
  #   {"type":"done","text":"…","notes":[…],"cost":0.01}
  #   {"type":"error","message":"…"}
  #
  # The job: {"path", "document", "start", "end", "instruction",
  # "turns": [{"instruction", "rewrite"}]}, offsets into "document".
  #
  # Two optional files shape every rewrite, under $XDG_CONFIG_HOME/omarky:
  #   writing.md or writing/*.md   a style guide, added to the system prompt
  #   check                        an executable run on the rewrite (as a .md
  #                                file); a non-zero exit sends its report
  #                                back to Claude once for another try
  class Rewrite
    MODEL = "claude-opus-5-5"
    EFFORT = "low"
    SCRUB = %w[CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_SESSION_ID CLAUDE_CODE_SSE_PORT].freeze

    SYSTEM = <<~TEXT.freeze
      You rewrite part of a Markdown document inside OmarkyWriter, a writing app. The writer has selected part of the document and given an instruction.

      Rewrite only the selected part, following the instruction. Reply with the replacement Markdown for the selection and nothing else: no preamble, no explanation, no quotation marks, and no code fence around it.

      Keep the Markdown structure of the selection (headings, lists, links, emphasis, line breaks between paragraphs) unless the instruction asks to change it. Keep the document's voice, tense, spelling conventions and facts. Add no claim the document does not support. Change nothing the instruction does not ask for. If the instruction cannot be applied, reply with the selection unchanged.
    TEXT

    def self.config_dir(env = ENV)
      File.join(env["XDG_CONFIG_HOME"].to_s.empty? ? File.join(Dir.home, ".config") : env["XDG_CONFIG_HOME"], "omarky")
    end

    # Claude Code on PATH, or where its installers put it.
    def self.claude(env = ENV)
      return env["OMARKY_CLAUDE"] unless env["OMARKY_CLAUDE"].to_s.empty?
      env["PATH"].to_s.split(":").each do |dir|
        p = File.join(dir, "claude")
        return p if File.file?(p) && File.executable?(p)
      end
      [File.join(Dir.home, ".local/bin/claude"), File.join(Dir.home, ".claude/local/claude"),
       File.join(Dir.home, ".local/share/mise/installs/claude/latest/claude")].find { File.executable?(_1) }
    end

    attr_reader :job, :notes, :cost

    def initialize(job, out: $stdout, env: ENV, config_dir: nil, claude: :find)
      @job = job
      @out = out
      @env = env
      @config_dir = config_dir || self.class.config_dir(env)
      @claude = claude == :find ? self.class.claude(env) : claude
      @notes = []
      @cost = 0.0
      @pid = nil
    end

    def guide
      single = File.join(@config_dir, "writing.md")
      files = File.file?(single) ? [single] : Dir.glob(File.join(@config_dir, "writing", "*.md")).sort
      files.map { File.read(_1).strip }.reject(&:empty?).join("\n\n")
    end

    def checker
      p = File.join(@config_dir, "check")
      File.file?(p) && File.executable?(p) ? p : nil
    end

    def system_prompt
      g = guide
      g.empty? ? SYSTEM : "#{SYSTEM}\nThe writer's style guide follows. Apply it to everything you write.\n\n#{g}\n"
    end

    def selection = @job.fetch("document")[@job.fetch("start")...@job.fetch("end")]

    def prompt
      doc = @job.fetch("document")
      a, b = @job.fetch("start"), @job.fetch("end")
      name = File.basename(@job["path"].to_s)
      parts = []
      parts << %(<document#{name.empty? ? "" : %( name="#{name}")}>\n#{doc[0...a]}<selection>#{doc[a...b]}</selection>#{doc[b..]}\n</document>)
      turns = Array(@job["turns"])
      unless turns.empty?
        parts << "Earlier rewrites of the selection, oldest first:"
        turns.each do |t|
          parts << "<attempt>\n<instruction>#{t['instruction']}</instruction>\n<rewrite>#{t['rewrite']}</rewrite>\n</attempt>"
        end
        parts << "Start from the last rewrite and apply the new instruction to it."
      end
      parts << "<instruction>#{@job.fetch('instruction')}</instruction>"
      parts << "Reply with only the new text for the selection."
      parts.join("\n\n")
    end

    def argv(prompt_text)
      [@claude, "-p", "--model", @env["OMARKY_REWRITE_MODEL"] || MODEL, "--effort", EFFORT,
       "--tools", "", "--setting-sources", "", "--strict-mcp-config", "--no-session-persistence",
       "--system-prompt", system_prompt,
       "--output-format", "stream-json", "--include-partial-messages", "--verbose", prompt_text]
    end

    def run
      return emit("error", message: "Claude Code is not installed (no claude on PATH).") unless @claude
      trap("TERM") { stop; exit 143 }
      text = ask(prompt)
      return 1 unless text
      if (c = checker) && !text.strip.empty?
        emit("checking")
        report = check(c, text)
        if report
          emit("retry", notes: report)
          again = ask(prompt + "\n\nYou replied:\n<rewrite>#{text}</rewrite>\n\nThe writer's checker reported these problems:\n#{report.join("\n")}\n\nFix them and reply with only the corrected text for the selection.")
          return 1 unless again
          text = again
          @notes = check(c, text) || []
        end
      end
      emit("done", text: text, notes: @notes, cost: @cost.round(4))
      0
    end

    # The final text of one Claude call, with its pieces streamed as they come.
    def ask(prompt_text)
      final = nil
      failed = nil
      streamed = +""
      err = +""
      status = nil
      Open3.popen3(env_for_claude, *argv(prompt_text), chdir: Dir.tmpdir) do |stdin, stdout, stderr, wait|
        @pid = wait.pid
        stdin.close
        errs = Thread.new { err << stderr.read.to_s }
        stdout.each_line do |line|
          o = JSON.parse(line) rescue next
          case o["type"]
          when "stream_event"
            d = o.dig("event", "delta")
            if d && d["type"] == "text_delta" && d["text"] && !failed
              streamed << d["text"]
              emit("text", text: d["text"])
            end
          when "result"
            @cost += o["total_cost_usd"].to_f
            if o["is_error"]
              failed = o["result"].to_s.empty? ? "Claude stopped with an error." : o["result"].to_s
            else
              final = o["result"].to_s
            end
          end
        end
        errs.join
        status = wait.value
        @pid = nil
      end
      if failed
        emit("error", message: failed)
        return nil
      end
      if final.nil?
        emit("error", message: err.strip.empty? ? "Claude ended without a reply (exit #{status&.exitstatus})." : err.strip.lines.last.strip)
        return nil
      end
      clean(final.empty? ? streamed : final)
    end

    # A reply wrapped whole in a code fence, when the selection was not code,
    # is unwrapped. Leading and trailing blank space follows the selection's.
    def clean(text)
      sel = selection
      t = text.dup
      if !sel.lstrip.start_with?("```", "~~~") && (m = t.strip.match(/\A```[\w-]*\n(.*)\n```\z/m))
        t = m[1]
      end
      t = t.strip
      lead = sel[/\A\s*/]
      trail = sel[/\s*\z/]
      lead + t + trail
    end

    # The checker's complaints, or nil when it passes.
    def check(checker, text)
      Tempfile.create(["omarky-rewrite", ".md"]) do |f|
        f.write(text.end_with?("\n") ? text : "#{text}\n")
        f.flush
        out, status = Open3.capture2e(checker, f.path)
        return nil if status.success?
        lines = out.lines.map(&:strip).reject(&:empty?)
        fixes = lines.grep(/\[fix\]/)
        (fixes.empty? ? lines : fixes).map { _1.sub(/\s*\|\s*L\d+:.*\z/, "").sub(/\A\[fix\]\s*/, "") }.uniq.first(12)
      end
    end

    def stop
      Process.kill("TERM", @pid) if @pid
    rescue Errno::ESRCH
      nil
    end

    def emit(type, **fields)
      @out.puts(JSON.generate({ type: type }.merge(fields)))
      @out.flush
      type == "error" ? 1 : 0
    end

    private

    def env_for_claude
      SCRUB.to_h { [_1, nil] }
    end
  end
end
