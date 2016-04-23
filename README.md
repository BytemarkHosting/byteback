byteback - maintenance-free client & server backup scripts for Linux
====================================================================

`byteback` encapsulates Bytemark's "best practice" for maintenance-free backups
with easy client and server setup.

"Maintenance-free" means that we'd rather make full use of a fixed amount of disc space.  Management of disc space must be completely automatic, so the process never grinds to a halt for reasons that could be automatically resolved.  Failed backups can be restarted in case of network problems.

We use the standard OpenSSH on the server for encrypted transport & access control, `btrfs` for simple snapshots and `rsync` for efficient data transfer across the network.

Backups should require as little configuration as possible to be safe - just the server address should be enough.


Setting up: server
------------------
Install the '`byteback`' package on the server, along with its dependencies.

You then need to perform the following local setup on the server, which can securely handle backups for multiple clients.  You need a dedicated user (which is usually called 'byteback') with a home directory on a btrfs filesystem.  You will need to mount the filesystem with the '`user_subvol_rm_allowed`' flag to enable pruning to work (or run that part as root).

The following commands are appropriate for a Debian system, you might need to alter it for other Linux distributions, or if you are not using LVM for your discs:

    #
	# Create a dedicated UNIX user which will store everyone's backups, and
	# allow logins
	#
	adduser --system byteback --home /byteback --shell /bin/bash

    #
	# Create a dedicated btrfs filesystem for the user, and add that as its home
	#
	lvcreate my_volume_group --name byteback --size 1000GB
	mkfs.btrfs /dev/my_volume_group/byteback
	echo '/dev/my_volume_group/byteback /byteback btrfs noatime,space_cache,compress=lzo,clear_cache,autodefrag,user_subvol_rm_allowed 0 0' >>/etc/fstab
	mount /byteback
	chown byteback /byteback
	chmod u+w /byteback

Finally, before setting up the client you should add the following to `/etc/ssh/sshd_config`, and restart the ssh-service:

  PermitUserEnvironment yes


Setting up: client
------------------
Clients are machines that need to be backed up.  Assuming you can log into the remote '`byteback`' user with a password or administrative key, you only need to type one command on the client to set things going:

	sudo byteback-setup-client --destination byteback@mybackuphost.net:

If this goes OK, you are ready to start backing up.  I'd advise taking the first backup manually to make sure it goes as you expect.  Type this on the client to start and watch the backup.

	sudo byteback-backup --verbose


Configuring byteback-backup
---------------------------

This is now documented in the manpage for byteback-backup(1).


Viewing and restoring backups
-----------------------------

This is now documented in the manpage for byteback-restore(1).


The trust model
---------------
Backups are intended to keep your data safe, and byteback makes the assumption that the client may become hostile to the backup server.  At Bytemark this allows us to guard against rogue employees of our clients destroying the backup, while ensuring that our clients can still access all their old backups.  There are several measures to guard against this, though they are all ineffective over a long enough period of time:

* the server uses SSH's command feature to ensure that clients can only run rsync to the appropriate directory;

* the server's snapshots are read-only, so the client can't just rsync an empty directory over an old backup;

* the server will refuse to take snapshots "too often" to stop the client from filling the disc with useless data;

* the server will refuse to prune away space for a new backup that is suddenly larger than previous ones.


Pruning behaviour
-----------------

This is now documented in byteback-prune(1).


Acknowledgements
----------------
For maximum portability, I've included three libraries.  Thanks very much to
their authors:

* sys-filesystem by Daniel J. Berger: https://github.com/djberg96/sys-filesystem
* trollop by William Morgan: https://github.com/wjessop/trollop
* ffi-xattr by Jari Bakken: https://github.com/jarib/ffi-xattr
