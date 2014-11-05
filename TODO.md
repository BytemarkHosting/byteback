TODO list for byteback
======================

* how do we stop backups from crashing server's kernel?
  * locking up completely (e.g. "touch newfile" never returns)
  * starting to run very very slowly until a btrfsck / remount
  * often nothing to do but "echo b > /proc/sysrq-trigger"

* give nilfs / zfs a go as alternatives?

* smarter logging defaults for cron jobs (to syslog)

* pruning doesn't work, assumes "btrfs  subvolume delete" is synchronous, which it is not.

* try to deal with https://btrfs.wiki.kernel.org/index.php/Problem_FAQ#I_get_.22No_space_left_on_device.22_errors.2C_but_df_says_I.27ve_got_lots_of_space ?

* (so introduce server-local cron job to keep on top of pruning and other stuff later)

* byteback-restore program

* out-of-date check should suspend judgment when backup is in progress

* add idea of progress on server side?

* clean ups: bundle trollop.rb, pull out cut & paste functions into library

* build include/exclude list more smartly, from /proc/mounts

* report differences between backups (new, deleted, changed files)

* spotting a /var/lib/mysql directory and making a safe snapshot and re-copy
  of a MySQL data directory (using FLUSH TABLES WITH READ LOCK)

* (same for postgres using pg_start_backup() and pg_stop_backup())

