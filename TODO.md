TODO list for byteback
======================

* byteback-prune does not cope with the case where the mount point is not
    writeable (should print error explaining that)

* retrieve scripts for checking status etc. from Bytemark managed hosts,
    integrate into main project.

* byteback-setup-client should support use of own accounts on server (i.e.
    not forcing you to ssh to byteback@server, change password etc.)

* byteback directory should be at the end of the load path, not start

* change default retry parameters to cover 24 hour window

* "backup could not be marked as complete" message unhelpful on client system - why?
    (should retry when SSH error == 255, otherwise give up)

* how do we stop backups from crashing server's kernel?
  * locking up completely (e.g. "touch newfile" never returns)
  * starting to run very very slowly until a btrfsck / remount
  * often nothing to do but "echo b > /proc/sysrq-trigger"

* give nilfs / zfs a go as alternatives?

* try to deal with https://btrfs.wiki.kernel.org/index.php/Problem_FAQ#I_get_.22No_space_left_on_device.22_errors.2C_but_df_says_I.27ve_got_lots_of_space ?

* out-of-date check should suspend judgment when backup is in progress

* add idea of progress on server side?

* report differences between backups (new, deleted, changed files)

* spotting a /var/lib/mysql directory and making a safe snapshot and re-copy
  of a MySQL data directory (using FLUSH TABLES WITH READ LOCK)

* (same for postgres using pg_start_backup() and pg_stop_backup())

jhackett@bm-jhackett:~$ sudo byteback-setup-client --destination byteback@byteback-server.default.tethra.uk0.bigv.io
No hostname set, using bm-jhackett.bytemark.co.uk

Skipping key generation, delete /etc/byteback/key if that's wrong
byteback@byteback-server.default.tethra.uk0.bigv.io's password: 
/usr/lib/ruby/1.9.1/fileutils.rb:247:in `mkdir': Permission denied - bm-jhackett.bytemark.co.uk (Errno::EACCES)
	from /usr/lib/ruby/1.9.1/fileutils.rb:247:in `fu_mkdir'
	from /usr/lib/ruby/1.9.1/fileutils.rb:221:in `block (2 levels) in mkdir_p'
	from /usr/lib/ruby/1.9.1/fileutils.rb:219:in `reverse_each'
	from /usr/lib/ruby/1.9.1/fileutils.rb:219:in `block in mkdir_p'
	from /usr/lib/ruby/1.9.1/fileutils.rb:205:in `each'
	from /usr/lib/ruby/1.9.1/fileutils.rb:205:in `mkdir_p'
	from /usr/bin/byteback-setup-client-receive:30:in `<main>'
*** Remote setup didn't work
jhackett@bm-jhackett:~$ sudo byteback-setup-client --destination byteback@byteback-server.default.tethra.uk0.bigv.io
No hostname set, using bm-jhackett.bytemark.co.uk

Skipping key generation, delete /etc/byteback/key if that's wrong
byteback@byteback-server.default.tethra.uk0.bigv.io's password: 
Create subvolume 'bm-jhackett.bytemark.co.uk/current'
Setup worked!  To take your first backup run: byteback-backup --verbose
jhackett@bm-jhackett:~$ sudo byteback-backup --verbose
system: ssh -o BatchMode=yes -o ConnectionAttempts=5 -o ConnectTimeout=30 -o ServerAliveInterval=60 -o TCPKeepAlive=yes -x -a -i /etc/byteback/key -l byteback@byteback byteback-server.default.tethra.uk0.bigv.io byteback-receive --ping --verbose
Permission denied (publickey,password).
*** Could not connect to byteback@byteback@byteback-server.default.tethra.uk0.bigv.io:
jhackett@bm-jhackett:~$ sudo -u ^Cyteback-backup --verbose
jhackett@bm-jhackett:~$ cd /etc/byteback/
jhackett@bm-jhackett:/etc/byteback$ ls
destination  key  key.pub
jhackett@bm-jhackett:/etc/byteback$ cat destination 
byteback@byteback@byteback-server.default.tethra.uk0.bigv.io
jhackett@bm-jhackett:/etc/byteback$ dpkg -l | ^C

