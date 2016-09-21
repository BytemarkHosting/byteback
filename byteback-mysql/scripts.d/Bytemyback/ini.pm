#!/usr/bin/perl

package Bytemyback::ini;

use warnings;
use strict;

use Data::Dumper;

use Exporter;
our @EXPORT_OK = qw(readconf writeconf generateconf);

# Didn't want to have to install any libraries on all servers.
# Couldn't find anything default and lightweight to read ini files
# So wrote this. Sorry.

sub readconf {
    my $file = shift || '/etc/byteback/mysql.ini';
    my %config;
    my $subsection = "default";
    return if !$file;
    open my $fh, "<", $file or return;
    foreach (<$fh>) {
        if (/^\s*\[([^\]]+)\]/) {
            $subsection = $1;
        }
        elsif (/^\s*(\S[^\s=]*)\s*=\s*(\S[^\s=]*)\s*$/) {
            $config{$subsection}->{$1}=$2;
        }
    }
    close $fh;
    return %config;
}

sub writeconf {
    # Hate writing code like this. @_ is the list of arguments passed to
    # this subroutine. It's either a file and a hash, or just a hash. A
    # hash is passed as a list of pairs of arguments (and Perl puts them
    # back into a hash). When used in scalar context, @_ returns the number
    # of items in the array. @_ % 2 is the remainder when this is divided by
    # 2 (modulo). So if it's either 1 if there are an odd number of elements
    # or 0. Perl treats 1 as true, 0 as false. So this one line with 10 lines
    # of explanation say if there are an odd number of elements, the first is
    # the ini file and should be shifted (removed from the front), otherwise
    # use a default.
    my $config_file = @_ % 2 ? shift : '/etc/byteback/mysql.ini';
    my %config = @_;
    open my $fh, ">", $config_file;
    foreach my $subsection (keys %config) {
        print $fh "[$subsection]\n";
        my $href = $config{$subsection};
        foreach my $key (keys %$href) {
            print $fh $key, " = ", $href->{$key}, "\n";
        }
    }
    close $fh;
}

sub generateconf {
    # Wipes current config, tries to figure out a set of defaults.
    # set LVM to 1 only if /etc/lvmbackup.conf exists
    # If it does, also populate LV size and whether or not to lock from there 
    my %backup_method = ( "lvm", 0, "mysqldump-split-db", 0, "mysqldump-full", 1 );
    # LVM specific variables
    my %lvm;
    # By default, lock tables. May be overridden below.
    $lvm{"lock"} = 1;
    my $lvmconfig = '/etc/mylvmbackup.conf';
    if (-e $lvmconfig) {    
        my $failed = 0;
        open my $conffh, "<", "/etc/mylvmbackup.conf" or $failed++;
        if ($conffh) {
            foreach (<$conffh>) {
                if (/^\s*lvsize=(\S+)\s*$/) {
                    $lvm{"lvsize"} = $1;
                }
                if (/^\s*skip_flush_tables=1/) {
                    $lvm{"lock"} = 0;
                }
            }
            close $conffh;
        }
        $backup_method{"lvm"} = 1;
    }
    else {
        $backup_method{"mysqldump-full"} = 1;
    }
    my %config = ( "backup_method" => \%backup_method, "lvm" => \%lvm );
    writeconf(%config);
    return(%config);
}
