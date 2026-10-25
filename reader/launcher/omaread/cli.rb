module OmaRead
  # The command line. Turns each argument into a target the window
  # understands, then hands the targets to the running window process over
  # IPC, or starts one with them in OMAREAD_OPEN.
  #
  # A target is "PATH[#anchor]" to read a file, or "PATH[#anchor]\tFROM\tTO"
  # to read it compared with an earlier version. FROM and TO are the raw
  # specs; the window resolves them by running `omaread PATH --resolve SPEC`.
  # An empty TO means now; `--changes` sends "before now" as FROM.
  class CLI
    LOG_RULES = "qt.qml.usedbeforedeclared=false;qt.qpa.services.warning=false"
    MODE_FLAGS = %w[--from --to --changes --list --resolve --versions]

    def initialize(argv, root:, name: File.basename($0))
      @argv = argv.dup
      @root = root
      @name = name
      @state = ENV["OMAREAD_STATE_DIR"] || File.join(ENV["XDG_STATE_HOME"] || File.join(Dir.home, ".local/state"), "omaread")
      @runtime = File.join(ENV["XDG_RUNTIME_DIR"] || "/tmp", "omaread")
      @instance = ENV["OMAREAD_INSTANCE"] || "omaread"
    end

    def run
      return help if @argv.include?("-h") || @argv.include?("--help")
      return version if @argv.include?("-V") || @argv.include?("--version")
      opts, files = parse(@argv)
      return opts if opts.is_a?(Integer)
      # Run as omachanges, a bare FILE means "show me its changes".
      opts["--changes"] = true if @name == "omachanges" && !opts["--from"] && !opts["--to"]
      mode = MODE_FLAGS.find { opts[_1] }
      targets = if mode
                  result = changes_target(opts, files, mode)
                  return result if result.is_a?(Integer)
                  [result]
                else
                  files.map { target_for(_1) }
                end
      open(targets, foreground: opts["--foreground"])
    end

    private

    # Flags into a hash, everything else is a file. Returns an exit status
    # when a flag that takes a value has none.
    def parse(argv)
      opts = {}
      files = []
      args = argv.dup
      until args.empty?
        a = args.shift
        case a
        when "--foreground", "--changes", "--list", "--versions" then opts[a] = true
        when "--from", "--to", "--resolve"
          opts[a] = args.shift or return error("#{a} needs a SPEC")
        else files << a
        end
      end
      [opts, files]
    end

    # "file.md#section" splits at the last "#", unless a file really has
    # that name. Paths are made absolute even when the file is missing: the
    # window shows a "cannot open" page for it.
    def split_target(arg)
      path = arg.sub(%r{\Afile://}, "")
      anchor = ""
      if !File.exist?(path) && path.include?("#")
        path, _, anchor = path.rpartition("#")
      end
      # Symlinks are resolved, as `realpath -m` did, so a file keeps one identity.
      full = File.expand_path(path)
      full = File.realpath(full) if File.exist?(full)
      [full, anchor]
    end

    def target_for(arg)
      path, anchor = split_target(arg)
      anchor.empty? ? path : "#{path}##{anchor}"
    end

    # The comparison flags: validate FILE, answer --list/--resolve/--versions,
    # or encode the FROM and TO specs for the window.
    def changes_target(opts, files, mode)
      label = @name == "omachanges" && mode == "--changes" && !@argv.include?("--changes") ? "omachanges" : mode
      return error("#{label} needs one FILE") unless files.size == 1
      file = files.first
      path, anchor = split_target(file)
      return error("#{file}: no such file") unless File.file?(path)
      history = History.new(path)
      now = ENV["OMAREAD_NOW"] ? Time.parse(ENV["OMAREAD_NOW"]) : Time.now
      resolver = Resolver.new(history, now: now)
      return print_json(Versions.summary(history, resolver)) if opts["--versions"]
      to = opts["--to"]
      from = opts["--from"]
      from ||= opts["--changes"] ? "before now" : (to ? "before #{to}" : nil)
      # Outside a work tree only "now" makes sense; anything else the user
      # asked for is a terminal error. (The window handles a bare "now" with
      # its own banner, from --versions.)
      specs = [opts["--from"], to, opts["--resolve"]].compact
      if !history.in_repo? && (opts["--list"] || opts["--changes"] || specs.any? { |s| s.strip.downcase != "now" })
        return error("#{file} is not in a git repository")
      end
      return list(history, resolver) if opts["--list"]
      return resolve(history, resolver, opts["--resolve"], to) if opts["--resolve"]
      "#{target_for(file)}\t#{from}\t#{to || ''}"
    end

    def list(history, resolver)
      history.versions.each do |v|
        d = resolver.display(v)
        puts [d["who"], d["when"], d["subject"]].join("\t")
      end
      0
    end

    # One side as JSON. With --to as well, the search stops before that
    # version, so "keith" against "--to danny" is Keith's last before Danny's.
    def resolve(history, resolver, spec, to_spec)
      bound = to_spec ? resolver.resolve(to_spec) : nil
      bound = nil if bound == :now
      v = resolver.resolve(spec, before: bound)
      print_json(Versions.side(history, resolver, v, history.disk_text))
    rescue Unresolved => e
      warn e.message
      1
    end

    def print_json(obj)
      puts JSON.generate(obj)
      0
    end

    def lock_path = File.join(@runtime, "#{@instance}.lock")

    # Fast path: a running instance holds the lock, so hand it the targets.
    # Otherwise start one detached qs process (or exec it in the foreground).
    def open(targets, foreground: false)
      ENV["XDG_DATA_DIRS"] = "#{Dir.home}/.local/share/omaread/ksh:#{ENV['XDG_DATA_DIRS'] || '/usr/local/share:/usr/share'}"
      if (pid = running_pid)
        ok = (targets.empty? ? [""] : targets).all? do |t|
          system("qs", "ipc", "--pid", pid, "call", "omaread", "open", t, out: File::NULL, err: File::NULL)
        end
        return 0 if ok
      end
      ENV["OMAREAD_OPEN"] = targets.join("\n")
      # Log rules: the minified markdown-it trips a declaration-order lint, and
      # Qt logs a portal app-ID clash on every Quickshell app (the Factory too);
      # neither is ours to fix (docs/decisions/0008).
      args = ["qs", "--log-rules", LOG_RULES, "-p", File.join(@root, "shell.qml")]
      exec(*args) if foreground
      FileUtils.mkdir_p(@state)
      log = File.open(File.join(@state, "qs.log"), "w")
      pid = fork do
        Process.setsid
        exec(*args, in: File::NULL, out: log, err: log)
      end
      log.close
      Process.detach(pid)
      0
    end

    # The pid in the lock file, when the lock is held and that pid is alive.
    def running_pid
      return nil unless File.file?(lock_path)
      File.open(lock_path) do |f|
        if f.flock(File::LOCK_EX | File::LOCK_NB)
          f.flock(File::LOCK_UN)
          return nil
        end
      end
      pid = File.read(lock_path).strip
      return nil if pid.empty?
      Process.kill(0, pid.to_i)
      pid
    rescue Errno::ESRCH, Errno::EPERM, Errno::ENOENT
      nil
    end

    # The header comment of bin/omaread, less the shebang.
    def help
      lines = File.readlines(File.join(@root, "bin/omaread")).drop(1).take_while { _1.start_with?("#") }
      puts lines.map { _1.sub(/\A# ?/, "") }
      0
    end

    def version
      puts "omaread #{File.read(File.join(@root, 'VERSION')).strip}"
      0
    end

    def error(msg)
      warn "omaread: #{msg}"
      2
    end
  end
end
