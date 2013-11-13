byteback - maintenance-free client & server backup scripts for Linux
====================================================================

byteback encapsulates Bytemark's "best practice" for maintenance-free backups
with easy client and server setup.

"Maintenance-free" means that we'd rather make full use of a fixed amount of
disc space with simple & predictable rules.  Management of disc space must be
completely automatic, so it never grinds to a halt.  Failed backups can be
restarted in case of network problems.

We use the standard OpenSSH on the server for encrypted transport & access 
control, btrfs for snapshots and rsync for efficient transfer.

Backups should require as little configuration as possible to be safe - just
the server address will be enough.

Setting up: server
------------------
Install the 'byteback' package on the server, along with its dependencies
(rsync, sudo).

Create a UNIX user to receive the backups e.g. 'byteback', create a btrfs
home directory with quotas enabled.

# adduser byteback
# echo 'byteback btrfs subvolume' XXX >>/etc/sudoers
# lvcreate my_volume_group -n byteback -L1000GB
# echo '/dev/my_volume_group /home/byteback btrfs compress 0 0' >>/etc/fstab
# mount /home/byteback
# btrfs quota enable /home/byteback

The server is launched from the 'byteback' user with OpenSSH as the transport,
so there is no special daemon to start, but you do need to set up the program's
data directory which is done with 

# su byteback
$ byteback-server setup

That's it!  You're now ready to start backing up your first client.

Setting up: client
------------------
Clients are machines that need to be backed up.  You need to tell each client
where its server is using normal SSH user/host syntax:

# byteback setup byteback@mybackuphost.net
Your backup key is ssh-rsa AAAAAo ... w== root@host.to.back.up
This will create keys for communication with the server, and put them into
/etc/byteback.  

You need to then log onto the server and inform it of this client, by using
the "byteback-server new-client" command and supplying the SSH public key.

# su byteback
$ byteback-server new-client ssh-rsa AAAAAo ... w== root@host.to.back.up
Client setup for host.to.back.up done!

This will have created a new directory and subvolume for this host's backups.
Then back on the client:

# byteback test
Connecting to server mybackuphost.net...
The authenticity of host 'mybackuphost.net (10.10.10.1)' can't be established.
RSA key fingerprint is c8:f5:bf:75:1b:34:6f:08:24:04:ba:a2:71:9f:5d:22.
Are you sure you want to continue connecting (yes/no)? yes
Successfully connected and found backup space, ready to go.

This means the host is ready to start backing up, though you need to set
a schedule.

Setting a backup schedule
-------------------------
You can then type "byteback backup" or put it on a daily cron job to start
backing up the server.

Without any further options this will copy every file from the root downwards,
excluding kernel-based virtual filesystems (/proc, /sys etc.) network 
filesystems (NFS, SMB) and tmpfs or loopback mounts.

When the backup has completed successfully, the server will take a snapshot
so that the client can't alter the backups.

If the backup is interrupted or dies unexpected, running "byteback backup" 
will cause the backup to be resumed, with rsync saving the work of re-copying
any files that hadn't changed.  By default this will happen automatically up to 
5 times, with a 10 minute pause in between each attempt.
