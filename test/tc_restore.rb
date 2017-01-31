require 'test/unit'
require 'byteback/restore'
require 'tmpdir'
require 'time'
require 'fileutils'

class RestoreTest < Test::Unit::TestCase

  def setup
    @byteback_root = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry_secure @byteback_root
  end

  def test_find
    create_snapshot_and_check_results(Time.now.iso8601.to_s)
  end

  def test_no_barf_on_non_timestamp_snapshot_name
    create_snapshot_and_check_results("saved-hacked-do-not-delete")
  end

  def create_snapshot_and_check_results(snapshot)
    FileUtils.mkdir_p(File.join(@byteback_root, snapshot))
    files = %w(/srv/foo.com/public/htdocs/index.html
               /srv/foo.com/public/htdocs/app.php)

    files.each do |f|
      FileUtils.mkdir_p(File.join(@byteback_root, snapshot, File.dirname(f)))
      FileUtils.touch(File.join(@byteback_root, snapshot, f))
      system("setfattr --name user.rsync.%stat -v \"41755 12,34 56:78\" #{File.join(@byteback_root, snapshot, f)}")
      assert_equal(0, $?.exitstatus)
    end

    r = Byteback::Restore.find(@byteback_root, "*", "/srv/foo.com/public/htdocs/*.html")
    assert(r.results.all?{|f| f.path =~ %r{/srv/foo.com/public/htdocs/.*.html}}, "Results returned did not match requested pattern")
    assert(r.results.all?{|f| f.snapshot == snapshot}, "Results returned were not from the correct snapshot")

    # Now check that we're getting the correct stuff from the rsync attr.
    f = r.results.first
    assert_equal(041755, f.mode, "Incorrect mode returned")
    assert_equal(12, f.dev_major, "Incorrect dev_major returned")
    assert_equal(34, f.dev_minor, "Incorrect dev_minor returned")
    assert_equal(56, f.uid, "Incorrect UID returned")
    assert_equal(78, f.gid, "Inocrrect GID returned")
  end

end
