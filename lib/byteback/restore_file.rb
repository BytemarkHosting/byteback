require 'ffi-xattr'
require 'scanf'
require 'pp'

module Byteback
  class RestoreFile
    S_IFMT = 0170000 #  bit mask for the file type bit fields

    S_IFSOCK = 0140000 #  socket
    S_IFLNK = 0120000 #  symbolic link
    S_IFREG = 0100000 #  regular file
    S_IFBLK = 0060000 #  block device
    S_IFDIR = 0040000 #  directory
    S_IFCHR = 0020000 #  character device
    S_IFIFO = 0010000 #  FIFO

    S_ISUID = 0004000 #  set-user-ID bit
    S_ISGID = 0002000 #  set-group-ID bit (see below)
    S_ISVTX = 0001000 #  sticky bit (see below)

    S_IRWXU = 00700 #  mask for file owner permissions
    S_IRUSR = 00400 #  owner has read permission
    S_IWUSR = 00200 #  owner has write permission
    S_IXUSR = 00100 #  owner has execute permission

    S_IRWXG = 00070 #  mask for group permissions
    S_IRGRP = 00040 #  group has read permission
    S_IWGRP = 00020 #  group has write permission
    S_IXGRP = 00010 #  group has execute permission

    S_IRWXO = 00007 #  mask for permissions for others (not in group)
    S_IROTH = 00004 #  others have read permission
    S_IWOTH = 00002 #  others have write permission
    S_IXOTH = 00001 #  others have execute permission

    include Comparable

    def initialize(full_path, byteback_root=".", now = Time.now)
      @full_path = full_path
      @byteback_root = byteback_root
      @now = now

      #
      # The snapshot is the first directory after the byteback_root
      #
      @snapshot = full_path.sub(%r(^#{Regexp.escape @byteback_root}),'').split("/")[1]

      if @snapshot == "current"
        @snapshot_time = @now
      else
        @snapshot_time = Time.parse(@snapshot)
      end

      #
      # Restore path
      #
      @path = full_path.sub(%r(^#{Regexp.escape @byteback_root}/#{Regexp.escape @snapshot}),'')

      @stat = @mode = @dev_major = @dev_minor = @uid = @gid = nil
    end

    def <=>(other)
      [self.path,  self.mtime.to_i,  self.size] <=> [other.path, other.mtime.to_i, other.size]
    end

    def stat
      @stat = ::File.lstat(@full_path) unless @stat.is_a?(File::Stat)
      @stat
    end

    def snapshot
      @snapshot
    end

    def snapshot_time
      @snapshot_time
    end

    def path
      @path
    end

    def to_s
      sprintf("%10s %i %4i %4i %s %s %s", self.modestring, self.size, self.uid, self.gid, self.mtime.strftime("%b %2d %H:%M"), @snapshot, @path)
    end

    def read_rsync_xattrs
      xattr = Xattr.new(@full_path, :no_follow => false)
      rsync_xattrs = xattr["user.rsync.%stat"]
      if rsync_xattrs
        @mode, @dev_major, @dev_minor, @uid, @gid = rsync_xattrs.scanf("%o %d,%d %d:%d")
        raise ArgumentError, "Corrupt rsync stat xattr found for #{@full_path} (#{rsync_xattrs})" unless [@mode, @dev_major, @dev_minor, @uid, @gid].all?{|i| i.is_a?(Integer)}
      else
        warn "No rsync stat xattr found for #{@full_path}" 
        @mode, @dev_major, @dev_minor, @uid, @gid = %w(mode dev_major dev_minor uid gid).collect{|m| self.stat.__send__(m.to_sym)}
      end
    end

    def mode
      return self.stat.mode if self.stat.symlink?
      read_rsync_xattrs unless @mode
      @mode
    end

    def dev_minor
      read_rsync_xattrs unless @dev_minor
      @dev_minor
    end

    def dev_major
      read_rsync_xattrs unless @dev_major
      @dev_major
    end

    def uid
      read_rsync_xattrs unless @uid
      @uid
    end

    def gid
      read_rsync_xattrs unless @gid
      @gid
    end

    #
    # This returns the type of file as a single character.
    #
    def ftypelet
      if file?
        "-"
      elsif directory?
        "d"
      elsif blockdev?
        "b"
      elsif chardev?
        "c"
      elsif symlink?
        "l"
      elsif fifo?
        "p"
      elsif socket?
        "s" 
      else
        "?"
      end 
    end

    #
    # This returns a modestring from the octal, like drwxr-xr-x.
    # This has mostly been copied from strmode from filemode.h in coreutils.
    #
    def modestring
      str = ""
      str << ftypelet
      str << ((mode & S_IRUSR == S_IRUSR) ? 'r' : '-')
      str << ((mode & S_IWUSR == S_IWUSR) ? 'w' : '-')
      str << ((mode & S_ISUID == S_ISUID) ?
                ((mode & S_IXUSR == S_IXUSR) ? 's' : 'S') :
                ((mode & S_IXUSR == S_IXUSR) ? 'x' : '-'))
      str << ((mode & S_IRGRP == S_IRGRP) ? 'r' : '-')
      str << ((mode & S_IWGRP == S_IWGRP) ? 'w' : '-')
      str << ((mode & S_ISGID == S_ISGID) ?
                ((mode & S_IXGRP == S_IXGRP) ? 's' : 'S') :
                ((mode & S_IXGRP == S_IXGRP) ? 'x' : '-'))
      str << ((mode & S_IROTH == S_IROTH) ? 'r' : '-')
      str << ((mode & S_IWOTH == S_IWOTH) ? 'w' : '-')
      str << ((mode & S_ISVTX == S_ISVTX) ?
                ((mode & S_IXOTH == S_IXOTH) ? 't' : 'T') :
                ((mode & S_IXOTH == S_IXOTH) ? 'x' : '-'))
      return str
    end

    def socket?
      (mode & S_IFMT) == S_IFSOCK
    end

    def symlink?
      self.stat.symlink? || (mode & S_IFMT) == S_IFLNK
    end

    def file?
      (mode & S_IFMT) == S_IFREG
    end

    def blockdev?
      (mode & S_IFMT) == S_IFBLK
    end

    def directory?
      (mode & S_IFMT) == S_IFDIR
    end

    def chardev?
      (mode & S_IFMT) == S_IFCHR
    end

    def fifo?
      (mode & S_IFMT) == S_IFIFO
    end

    def readlink
      if self.stat.symlink?
        File.readlink(@full_path)
      else
        File.read(@full_path).chomp
      end
    end

    def method_missing(m, *args, &blk)
      return self.stat.__send__(m) if self.stat.respond_to?(m)

      raise NoMethodError, m
    end 
  end
end
