byteback - maintenance-free client & server backup scripts for Linux
====================================================================

byteback encapsulates Bytemark's "best practice" for maintenance-free backups
with easy client and server setup.

"Maintenance-free" means that we'd rather make full use of a fixed amount of
disc space.  Management of disc space must be completely automatic, so the
process never grinds to a halt for reasons that could be automatically 
resolved.  Failed backups can be restarted in case of network problems.

We use the standard OpenSSH on the server for encrypted transport & access 
control, btrfs for simple snapshots and rsync for efficient data transfer
across the network.

Backups should require as little configuration as possible to be safe - just
the server address should be enough.

Setting up: server
------------------
Install the 'byteback' package on the server, along with its dependencies
(rsync and ruby-ffi).

You then need to perform the following local setup on the server, which can
securely handle backups for multiple clients.  You need a dedicated user
(which is usually called 'byteback') with a home directory on a btrfs 
filesystem.  You will need to mount the filesystem with the 
'user_subvol_rm_allowed' flag to enable pruning to work (or run that part
as root).

The following commands are appropriate for a Debian system, you might need 
to alter it for other Linux distributions, or if you are not using LVM
for your discs:

	# Create a dedicated UNIX user which will store everyone's backups, and
	# allow logins
	#
	adduser --system byteback --home /byteback --shell /bin/bash

	# Create a dedicated btrfs filesystem for the user, and add that as its home
	#
	lvcreate my_volume_group --name byteback --size 1000GB
	mkfs.btrfs /dev/my_volume_group/byteback
	echo '/dev/my_volume_group/byteback /byteback btrfs noatime,space_cache,compress=lzo,clear_cache,autodefrag,user_subvol_rm_allowed 0 0' >>/etc/fstab
	mount /byteback
	chown byteback /byteback
	chmod u+w /byteback

Finally, before setting up the client, add 

  PermitUserEnvironment yes

to /etc/ssh/sshd_config, and restart sshd.

Setting up: client
------------------
Clients are machines that need to be backed up.  Assuming you can log into
the remote 'byteback' user with a password or administrative key, you only
need to type one command on the client to set things going:

	sudo byteback-setup-client --destination byteback@mybackuphost.net:

If this goes OK, you are ready to start backing up.  I'd advise taking the
first backup manually to make sure it goes as you expect.  Type this on the
client to start and watch the backup.

	sudo byteback-backup --verbose

Configuring byteback-backup
---------------------------
You can now set "byteback-backup"  on a daily cron job to start backing up the
server on a regular basis.

Without any further options this will copy every file from the root downwards.

It currently excludes /tmp, /var/tmp, /var/cache/apt/archives, /swap.file and
/var/backups/localhost which (on Bytemark systems) do not need to be part of
any backup.  To specify which locations are excluded, add them to
/etc/byteback/excludes, one per line.  The filesystems /dev, /proc, /run and
/sys are always excluded.

It is possible to configure a full rsync filter by creating the file
/etc/byteback/rsync_filter, which is parsed to rsync via the --filter flag.
Note that excludes on the command line take precedence, unless the filter
starts with an exclamation mark, which resets everything.  If you do this,
you'll need to specify /proc, /sys, etc manually.  See the rsync manpage for
more information about filters.

It is also possible to add extra rsync flags to the configuration.  The
following flags are always set:

  --archive --numeric-ids --delete-delay --inplace --relative --timeout 43200

If you wish to add to that (e.g. --xattrs --acl --hard-links) then simply add
them to /etc/byteback/rsync_flags.  These extra flags get appended after the
default flags above, so they take precedence.

When the backup has completed successfully, the server will take a snapshot
so that the client can't alter the backups, and then "prune" the backup 
snapshots to ensure that the next backup is likely to run OK.

If the backup is interrupted or dies unexpected, running "byteback backup" 
will cause the backup to be resumed, with rsync saving the work of re-copying
any files that hadn't changed.  By default this will happen automatically up to 
5 times, with a 10 minute pause in between each attempt.

Viewing and restoring backups
-----------------------------

Backups can be viewed on the server filesystem, although the permissions will
be wrong.  The rsync "fake-super" flag is used to store the permissions in a
user attribute list.  To view this list on the server, run 

  getfattr -d  $filename

This command is part of the "attr" package in Debian.

To restore a file to the current directory, you need to run:

  rsync -Prat --rsync-path='rsync --fake-super' byteback@mybackuphost.net:path/to/file .

The --fake-super flag only applies to the "local" end, hence the need to specfy
the rsync-path.  You'll need to set up correct SSH permissions at the remote
end for this to work.

The trust model
---------------
Backups are intended to keep your data safe, and byteback makes the assumption
that the client may become hostile to the backup server.  At Bytemark this
allows us to guard against rogue employees of our clients destroying the backup,
while ensuring that our clients can still access all their old backups.  There
are several measures to guard against this, though they are all ineffective
over a long enough period of time:

* the server uses SSH's command feature to ensure that clients can only
  run rsync to the appropriate directory;

* the server's snapshots are read-only, so the client can't just rsync an
  empty directory over an old backup;

* the server will refuse to take snapshots "too often" to stop the client
  from filling the disc with useless data;

* the server will refuse to prune away space for a new backup that is
  suddenly larger than previous ones.

Pruning behaviour
-----------------
Unless you are backing up a very small amount of data, backups will always 
need pruning, i.e. old backups must be deleted to make way for newer ones.

There is a program on the server called byteback-prune which deals with this
operation.  It deletes old backups until a certain amount of free space is
achieved, which is currently fixed at 10% free.  This can be changed by setting
the --maxpercent option.

It can choose which backups to delete by one of two methods:

1) the 'age' method simply deletes the oldest backup;

2) the 'importance' method tries to retain a more spread-out backup pattern
by "scoring" each backup according to how close it is to a set of "target 
times".  These are:

 * midday today;
 * midday on the previous 6 days;
 * midday on the previous 4 Sundays;
 * midday on every 4th Sunday before that.

So when you ask the pruner to run, the backup closest to the present time will
be the last one to be deleted.  The backup closes to "1 day ago" will be the
second-last, and so on.  We score every backup in this way until we end up with
a "least important" snapshot to delete.

The upshot of the second strategy should be that we retain closely-spaced
daily backups, but as they get too numerous, we make sure that we are reluctant
to delete our very oldest.

The "4th Sunday" is calculated as every 4th Sunday in the Unix epoch, i.e.
every fourth Sunday since Sunday 4th Jan 1970. 

Acknowledgements
----------------
For maximum portability, I've included two libraries.  Thanks very much to
their authors:

sys-filesystem by Daniel J. Berger: https://github.com/djberg96/sys-filesystem
trollop by William Morgan: https://github.com/wjessop/trollop
