module Omarky
  # The library's one native piece, the editor's highlighter (native/), built
  # with CMake into an app's build/ directory:
  #
  #   native = Omarky::Native.new(root: ROOT, source: "#{ROOT}/vendor/omarky/native", state_dir: app.state_dir)
  #   path = native.ensure            # the import path, or nil when it cannot be built
  #   app.open(targets, env: { "QML_IMPORT_PATH" => path })
  #
  # The module is rebuilt when it is missing, when a source under native/ is
  # newer than it, or when Qt has been upgraded (it uses one private Qt
  # header, decision 0015), and the Qt version it was built against is kept
  # in build/qt-version. Output goes to <state_dir>/build.log.
  class Native
    class BuildFailed < StandardError; end

    MODULE = "Omarky/Native/libomarkynative.so"

    attr_reader :root, :source, :build, :state_dir

    def initialize(root:, source:, state_dir:, build: File.join(root, "build"), qt: nil, builder: nil)
      @root = root
      @source = source
      @state_dir = state_dir
      @build = build
      @qt = qt
      @builder = builder
    end

    def import_path = File.join(@build, "qml")
    def module_path = File.join(import_path, MODULE)
    def version_path = File.join(@build, "qt-version")
    def log_path = File.join(@state_dir, "build.log")

    # The installed Qt's version, "" when qtpaths is missing.
    def qt_version
      @qt ||= `/usr/lib/qt6/bin/qtpaths --qt-version 2>/dev/null`.strip
    end

    def built_against
      File.read(version_path).strip
    rescue Errno::ENOENT
      ""
    end

    def stale?
      return true unless File.file?(module_path)
      built = File.mtime(module_path)
      return true if Dir.glob(File.join(@source, "**/*")).any? { |f| File.file?(f) && File.mtime(f) > built }
      qt_version != built_against
    end

    def cmake?
      (ENV["PATH"] || "").split(":").any? { |d| File.executable?(File.join(d, "cmake")) }
    end

    # The import path, building first when the module is stale. Returns nil
    # when there is no cmake or the build fails, or raises BuildFailed when
    # `required`. The failure's detail is in build.log.
    def ensure(required: false)
      return import_path unless stale?
      unless cmake?
        raise BuildFailed, "cmake is not installed" if required
        return nil
      end
      FileUtils.mkdir_p(@state_dir)
      ok = (@builder || method(:cmake_build)).call
      unless ok
        raise BuildFailed, "building the native highlighter failed; see #{log_path}" if required
        return nil
      end
      FileUtils.mkdir_p(@build)
      File.write(version_path, "#{qt_version}\n")
      import_path
    end

    private

    def cmake_build
      gen = ninja? ? ["-G", "Ninja"] : []
      system("cmake", "-S", @source, "-B", @build, *gen, "-DCMAKE_BUILD_TYPE=Release", out: log_path, err: log_path) &&
        system("cmake", "--build", @build, out: [log_path, "a"], err: [log_path, "a"])
    end

    def ninja?
      (ENV["PATH"] || "").split(":").any? { |d| File.executable?(File.join(d, "ninja")) }
    end
  end
end
