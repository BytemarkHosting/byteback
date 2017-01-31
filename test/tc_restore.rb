require 'test/unit'
require 'byteback/restore'
require 'tmpdir'
require 'time'
require 'fileutils'

class RestoreTest < Test::Unit::TestCase

  def setup
    @byteback_root = Dir.mktmpdir
    @snapshot = Time.now.iso8601
    FileUtils.mkdir_p(File.join(@byteback_root, @snapshot))
  end

  def teardown
    FileUtils.remove_entry_secure @byteback_root
  end

  def test_find
    files = %w(/srv/foo.com/public/htdocs/index.html
               /srv/foo.com/public/htdocs/app.php)

    files.each do |f|
      FileUtils.mkdir_p(File.join(@byteback_root, @snapshot, File.dirname(f)))
      FileUtils.touch(File.join(@byteback_root, @snapshot, f))
      system("setfattr --name user.rsync.%stat -v \"41755 12,34 56:78\" #{File.join(@byteback_root, @snapshot, f)}")
    end

    r = Byteback::Restore.find(@byteback_root, "*", "/srv/foo.com/public/htdocs/*.html")
  
    r.list 
  end

end
