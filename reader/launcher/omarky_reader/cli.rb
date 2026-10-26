module OmarkyReader
  # The command line. Turns each argument into a target the window
  # understands, then hands the targets to the running window process over
  # IPC, or starts one with them in OMARKY_READER_OPEN.
  #
  # A target is "PATH[#anchor]" to read a file, or "PATH[#anchor]\tFROM\tTO"
  # to read it compared with an earlier version. FROM and TO are the raw
  # specs; the window resolves them by running `omarky read PATH --resolve SPEC`.
  # An empty TO means now; `--changes` sends "before now" as FROM.
  #
  # `omarky read …` and `omarky changes …` (changes: true, where a bare FILE
  # means "show me its changes") both come here from bin/omarky.
  class CLI
    MODE_FLAGS = %w[--from --to --changes --list --resolve --versions]

    def initialize(argv, root:, changes: false)
      @argv = argv.dup
      @root = root
      @changes = changes
      @app = Omarky::Instance.new(name: "omarky-reader", root: root, shell: "reader/ui/shell.qml", bin: "bin/omarky", prefix: "OMARKY_READER")
      @native = Omarky::Native.new(root: root, source: File.join(root, "native"), state_dir: @app.state_dir)
    end

    def run
      return help if @argv.include?("-h") || @argv.include?("--help")
      opts, files = parse(@argv)
      return opts if opts.is_a?(Integer)
      return build if opts["--build"]
      opts["--changes"] = true if @changes && !opts["--from"] && !opts["--to"]
      mode = MODE_FLAGS.find { opts[_1] }
      targets = if mode
                  result = changes_target(opts, files, mode)
                  return result if result.is_a?(Integer)
                  [result]
                else
                  files.map { target_for(_1) }
                end
      @app.open(targets, foreground: opts["--foreground"], env: native_env)
    end

    # The editor's highlighter (the sheet) is built when it can be; a reader
    # opens without it on a machine with no cmake or Qt headers.
    def native_env
      return {} if @app.running_pid
      path = @native.ensure
      path ? { "QML_IMPORT_PATH" => [path, ENV["QML_IMPORT_PATH"]].compact.reject(&:empty?).join(":") } : {}
    end

    def build
      puts @native.ensure(required: true)
      0
    rescue Omarky::Native::BuildFailed => e
      error(e.message)
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
        when "--foreground", "--changes", "--list", "--versions", "--build" then opts[a] = true
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
      label = @changes && mode == "--changes" && !@argv.include?("--changes") ? "changes" : mode
      return error("#{label} needs one FILE") unless files.size == 1
      file = files.first
      path, anchor = split_target(file)
      return error("#{file}: no such file") unless File.file?(path)
      history = Omarky::History.new(path)
      now = ENV["OMARKY_NOW"] ? Time.parse(ENV["OMARKY_NOW"]) : Time.now
      resolver = Omarky::Resolver.new(history, now: now)
      return print_json(Omarky::Versions.summary(history, resolver)) if opts["--versions"]
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
      print_json(Omarky::Versions.side(history, resolver, v, history.disk_text))
    rescue Omarky::Unresolved => e
      warn e.message
      1
    end

    def print_json(obj)
      puts JSON.generate(obj)
      0
    end

    def help = @app.help(File.join(@root, "bin/omarky"))

    def error(msg)
      warn "omarky: #{msg}"
      2
    end
  end
end
