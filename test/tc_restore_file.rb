require 'test/unit'
require 'byteback/restore_file'
require 'tempfile'
require 'tmpdir'

class BytebackFileTest < Test::Unit::TestCase
  def setup
    @byteback_root = Dir.mktmpdir
    now = Time.now
    @snapshot = Time.local(now.year, now.month, now.day, now.hour, now.min)
    @snapshot_path = File.join(@byteback_root, @snapshot.strftime('%Y-%m-%dT%H:%M%z'))
    FileUtils.mkdir_p(@snapshot_path)
  end

  def teardown
    FileUtils.remove_entry_secure @byteback_root
  end

  def test_general
    f = Tempfile.new('restore-file-', @snapshot_path)
    system("setfattr --name user.rsync.%stat -v \"41755 12,34 56:78\" #{f.path}")
    b = Byteback::RestoreFile.new(f.path, @byteback_root)
    assert_equal(041755, b.mode)
    assert_equal(12, b.dev_major)
    assert_equal(34, b.dev_minor)
    assert_equal(56, b.uid)
    assert_equal(78, b.gid)
    assert_equal('drwxr-xr-t', b.modestring)
    assert_equal(@snapshot, b.snapshot_time)
    assert_kind_of(Time, f.mtime)
  end
end
