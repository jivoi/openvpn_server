#!/usr/bin/perl

use strict;
use DBI;
use Digest::MD5 qw(md5_hex);

# Master database (always used first to save logs)
my $dbmh = DBI->connect('dbi:mysql:database=vpn;host=127.0.0.1;port=3306',
                        'vpn',
                        'P@ssw0rd',
                        {}
) or die("Cannot connect to master database.");

# Slave database (on first server equals master database)
my $dbsh = $dbmh;

my $usertable = 'users_admins';
my $logtable = 'log_admins';

my $username = $ENV{'username'};
my $password = $ENV{'password'};

if (!$username || !$password) {
    print 'Username or password does not exist.';
    exit 1;
}

my ($sth, $query);

# There is primary key on try_time column of logtable in database.
# This limits speed of auth to one per second, which is additional security.
$query = "INSERT $logtable VALUES ('$username', now())";
$sth = $dbmh->do($query) or $dbsh->do($query) or die $dbmh->errstr() . $dbsh->errstr();

$sth = $dbsh->prepare("SELECT username FROM $usertable WHERE username=? and password=? and valid_through >= now()") or die $dbsh->errstr();
$sth->execute($username, md5_hex($password)) or die $dbsh->errstr();

if (($sth->fetchrow_array())[0] eq $username) {
    print "Access GRANTED for user: $username.\n";
    $query = "UPDATE $usertable SET last_login = NOW() WHERE username='$username'";
    $sth = $dbmh->do($query) or $dbsh->do($query) or die $dbmh->errstr() . $dbsh->errstr();
    exit 0;
}

print "Access DENIED for user: '$username' and password: '$password'.\n";
#print "\n".md5_hex($password)."\n";
exit 1;
