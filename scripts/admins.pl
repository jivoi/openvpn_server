#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $usertable='users_admins';
my $logtable='log_admins';
my $dbh = DBI->connect('dbi:mysql:database=vpn;host=127.0.0.1;port=3306',
                       'vpn',
                       'P@ssw0rd',
                       {}
) or die "Could not connect to the database";

sub help {
    print "Help:\n";
    print " add <login> <'realname'> <'reged_by_request_of'> <'valid_through'> \t- add user,\n";
    print "\t\t\t\t\t\t\t\t\t  which is valid up to 200?-??-??\n";
    print "\t\t\t\t\t\t\t\t\t  any additional arguments go to comments\n";
    print " del <login> \t\t- delete user\n";
    print " list [login] \t\t- list ALL users or only login with LIKE search\n";
    print " pass <login> [pass] \t- change password for user with optional custom password\n";
}

sub list_vpn_users {
    my $pattern = $_[0];
    my $sth;
    if ($pattern eq '') {
        $sth = $dbh->prepare("SELECT u.username, u.realname, u.last_login, max(l.try_time) FROM $usertable u LEFT JOIN $logtable l USING (username) GROUP BY u.username ORDER BY l.try_time") or die $dbh->errstr();
        $sth->execute or die $dbh->errstr();
    } else {
        $sth = $dbh->prepare("SELECT u.username, u.realname, u.last_login, max(l.try_time) FROM $usertable u LEFT JOIN $logtable l USING (username) WHERE u.username LIKE ? or u.realname LIKE ? or u.comment LIKE ? GROUP BY u.username ORDER BY l.try_time") or die $dbh->errstr();
        $sth->execute("%$pattern%", "%$pattern%", "%$pattern%") or die $dbh->errstr();
    }
    print "USERNAME\t\tREALNAME\t\tLAST LOGIN\tLAST LOGIN TRY\n";
    while (my @row = $sth->fetchrow_array()) {
        print "$row[0]\t\t$row[1]\t$row[2]\t$row[3]\n";
    }
    $sth->finish();
}

sub exist_user {
    my $username=$_[0];
    my $sth = $dbh->prepare("SELECT username from $usertable where username=?") or die $dbh->errstr;
    $sth->execute($username) or die $dbh->errstr();
    my @row =$sth->fetchrow_array();
    if ($row[0] eq $username) {
        return "YES";
    } else { 	
        return "NO"
    };
}

sub add {
    my $username = $_[0];
    my $realname = $_[1];
    my $reged_by_request_of = $_[2];
    my $valid_through = $_[3];
    my $comment = $_[4];
    if (exist_user($username) eq 'YES') {
        print "User $username already exist.\n";
        exit 1;
    }
    if ($valid_through !~ /^\d{4}-\d{2}-\d{2}$/) {
        print "Validity date for user $username was incorrect: $valid_through.\n";
        print "Date must be on format YYYY-MM-DD.\n";
        exit 1;
    }
    my $userpassword = `/usr/local/etc/openvpn/scripts/genpass`;
    chomp($userpassword);
    my $cryptpassword = md5_hex($userpassword);
    my $sth = $dbh->prepare("INSERT $usertable(username, realname, regtime, password, reged_by_request_of, valid_through, comment) values (?, ?, now(), ?, ?, ?, ?)") or die $dbh->errstr();
    $sth->execute($username, $realname, $cryptpassword, $reged_by_request_of, $valid_through, $comment) or die $dbh->errstr();
    print "Added user $username with password '$userpassword'.\n";
}

sub del {
    my $username=$_[0];
    if (exist_user($username) eq 'NO') {
        print "User $username does not exist.\n";
        exit 1;
    }
    my $sth = $dbh->prepare("DELETE from $usertable where username=?") or die $dbh->errstr();
    $sth->execute($username) or die $dbh->errstr();
    print "User $username has been deleted.\n";
}

sub pass {
    my $username=$_[0];
    my $userpassword=$_[1];
    if (exist_user($username) eq 'NO') {
            print "User $username does not exist.\n";
            exit 1;
    }
    if (!$userpassword) { $userpassword =`/usr/local/etc/openvpn/scripts/genpass`; }
    chomp ($userpassword);
    my $cryptpassword = md5_hex($userpassword);
    my $sth = $dbh->prepare("UPDATE $usertable SET password=? WHERE username=?") or die $dbh->errstr;
    $sth->execute($cryptpassword, $username) or die $dbh->errstr();
    print "User $username updated with password '$userpassword'.\n";
}

my $action = $ARGV[0];

if ($action eq 'list') {
    list_vpn_users(lc($ARGV[1]));
    exit 0;
}

if ($action eq 'add') {
    my $comment = '';
    if (!$ARGV[1] || !$ARGV[2] || !$ARGV[3] || !$ARGV[4]) {
        help();
        exit 1;
    }
    for (my $i = 5; $i <= $#ARGV; $i++) {
        $comment = $comment . ' ' . $ARGV[$i];
    }
    $comment =~ s/^\s//g;
    add(lc($ARGV[1]), $ARGV[2], $ARGV[3], $ARGV[4], $comment);
    exit 0;
}

if ($action eq 'del') {
    if (!$ARGV[1]) {
        help();
        exit 1;
    }
    del(lc($ARGV[1]));
    exit 0;
}

if ($action eq 'pass') {
    if ( !$ARGV[1] ) {
        help();
        exit 1;
    }
    pass(lc($ARGV[1]), $ARGV[2]);
    exit 0;
}

$dbh->disconnect();
help();
exit 1;
