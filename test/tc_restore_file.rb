$: << File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'byteback/restore_file'
require 'tempfile'

class BytebackFileTest < Test::Unit::TestCase

  def test_general
    f = Tempfile.new($0)
    system("setfattr --name user.rsync.%stat -v \"41755 12,34 56:78\" #{f.path}")
    b = Byteback::RestoreFile.new(f.path)
    assert_equal(041755, b.mode)
    assert_equal(12, b.maj)
    assert_equal(34, b.min)
    assert_equal(56, b.uid)
    assert_equal(78, b.gid)
    assert_equal("drwxr-xr-t", b.modestring)
    assert_kind_of(Time, f.mtime)
  end

end
