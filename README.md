byteback - maintenance-free client & server backup scripts for Linux
====================================================================

byteback encapsulates Bytemark's "best practice" for maintenance-free backups
with easy client and server setup.

"Maintenance-free" means that we'd rather make full use of a fixed amount of
disc space with simple & predictable rules.  Management of disc space must be
completely automatic, so the process never grinds to a halt for reasons that
could be automatically resolved.  Failed backups can be restarted in case of
network problems.

We use the standard OpenSSH on the server for encrypted transport & access 
control, btrfs for simple snapshots and rsync for efficient data transfer
across the network.

Backups should require as little configuration as possible to be safe - just
the server address should be enough.

Setting up: server
------------------
Install the 'byteback' package on the server, along with its dependencies
(rsync, sudo).

You then need to perform the following local setup on the server, which can
securely handle backups for multiple clients.  The following commands are
appropriate for a Debian system, you might need to alter it for other Linux
distributions:

	# Create a dedicated UNIX user which will store everyone's backups, and
	# allow logins
	#
	adduser --system byteback --home /byteback --shell /bin/bash

	# Allow the backup user to run the snapshot command
	#
	# echo <<SUDOERS >/etc/sudoers.d/byteback
	byteback ALL = (root) NOPASSWD: /usr/local/bin/byteback-snapshot
	byteback ALL = (root) NOPASSWD: /usr/bin/byteback-snapshot
	byteback ALL = (root) NOPASSWD: /sbin/btrfs subvolume create
	Defaults:byteback !requiretty
	SUDOERS

	# Create a dedicated btrfs filesystem for the user, and add that as its home
	#
	lvcreate my_volume_group --name byteback --size 1000GB
	mkfs.btrfs /dev/my_volume_group/byteback
	echo '/dev/my_volume_group/byteback /byteback btrfs compress 0 0' >>/etc/fstab
	mount /byteback

Setting up: client
------------------
Clients are machines that need to be backed up.  Assuming you can log into
the remote 'byteback' user with a password or administrative key, you only
need to type one command on the client to set things going:

	byteback-setup-client --destination byteback@mybackuphost.net:

If this goes OK, you are ready to start backing up.  I'd advise taking the
first backup manually to make sure it goes as you expect.  Type this on the
client to start and watch the backup.

	byteback-backup --verbose

Configuring byteback-backup
---------------------------
You can now set "byteback backup"  on a daily cron job to start backing up the
server on a regular basis.

Without any further options this will copy every file from the root downwards,
excluding kernel-based virtual filesystems (/proc, /sys etc.) network 
filesystems (NFS, SMB) and tmpfs or loopback mounts.

It currently excludes /swap.file and /var/backups/localhost which (on Bytemark
systems) do not need to be part of any backup.

When the backup has completed successfully, the server will take a snapshot
so that the client can't alter the backups, and then "prune" the backup 
snapshots to ensure that the next backup is likely to run OK.

If the backup is interrupted or dies unexpected, running "byteback backup" 
will cause the backup to be resumed, with rsync saving the work of re-copying
any files that hadn't changed.  By default this will happen automatically up to 
5 times, with a 10 minute pause in between each attempt.

Pruning behaviour
-----------------

Features to come
----------------
* spotting a /var/lib/mysql directory and making a safe snapshot and re-copy
  of a MySQL data directory (using FLUSH TABLES WITH READ LOCK)

* (same for postgres using pg_start_backup() and pg_stop_backup())

