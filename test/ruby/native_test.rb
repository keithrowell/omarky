require "test_helper"
require "tmpdir"

class NativeTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("omarky-native")
    @source = File.join(@dir, "native")
    FileUtils.mkdir_p(@source)
    File.write(File.join(@source, "a.cpp"), "int x;\n")
    @builds = 0
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def native(qt: "6.11.0", fail: false)
    Omarky::Native.new(root: @dir, source: @source, state_dir: File.join(@dir, "state"), qt: qt,
                       builder: lambda {
                         @builds += 1
                         next false if fail
                         FileUtils.mkdir_p(File.dirname(mod))
                         File.write(mod, "so")
                         true
                       })
  end

  def mod = File.join(@dir, "build/qml", Omarky::Native::MODULE)

  def test_builds_when_the_module_is_missing_and_records_qt
    n = native
    assert_equal File.join(@dir, "build/qml"), n.ensure
    assert_equal 1, @builds
    assert_equal "6.11.0", n.built_against
    assert_equal "6.11.0\n", File.read(File.join(@dir, "build/qt-version"))
  end

  def test_a_fresh_module_is_not_rebuilt
    native.ensure
    assert_equal File.join(@dir, "build/qml"), native.ensure
    assert_equal 1, @builds
  end

  def test_a_newer_source_rebuilds
    native.ensure
    future = Time.now + 60
    File.utime(future, future, File.join(@source, "a.cpp"))
    native.ensure
    assert_equal 2, @builds
  end

  def test_a_new_qt_rebuilds
    native.ensure
    native(qt: "6.12.0").ensure
    assert_equal 2, @builds
  end

  def test_a_failed_build_returns_nil_or_raises
    assert_nil native(fail: true).ensure
    err = assert_raises(Omarky::Native::BuildFailed) { native(fail: true).ensure(required: true) }
    assert_match(/build\.log/, err.message)
  end

  def test_no_cmake_without_required_is_nil
    n = native
    n.define_singleton_method(:cmake?) { false }
    assert_nil n.ensure
    assert_raises(Omarky::Native::BuildFailed) { n.ensure(required: true) }
    assert_equal 0, @builds
  end
end
