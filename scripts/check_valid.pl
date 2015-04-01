#!/usr/bin/env perl

# check valid through passwords for vpn access
# v.0.1

use strict;
use DBI;
use MIME::Base64 qw(encode_base64);

my $sendmail = "/usr/bin/env sendmail";

my $dbh = DBI->connect('dbi:mysql:database=vpn;host=127.0.0.1;port=3306', 'vpn', 'P@ssw0rd', {}
) or die("Cannot connect to master database.");

my $usertable = 'users';

my @days = ('14', '7', '3', '2', '1');

my $sql = "SELECT username,email FROM $usertable WHERE valid_through=CURDATE()+INTERVAL ? DAY;";
my $sth = $dbh->prepare($sql);

my $user;
my $email;

foreach my $i (@days) {
    $sth->bind_param(1, $i);
    $sth->execute() or die $dbh->errstr();
    while ( ($user,$email) = $sth->fetchrow_array() ) {
    if ( ! $email ) { 
#           print "email: " . $email . "\n";
        $email = "root\@example.ru"
    }

        print "user: " . $user . "\n";
        print "e-mail: " . $email . "\n";

        my $subject = encode_base64("Пароль у $user устареет через $i дней", "");
            $subject = "=?utf8?B?".$subject."?=";

            my @head;
            push(@head, "To: " . $email . "\n");
            push(@head, "From: adm\@example.ru\n");
        push(@head, "Subject: " . $subject . "\n");
            push(@head, "Mime-Version: 1.0\n");
            push(@head, "Type: multipart/mixed\n");
            push(@head, "Content-type: multipart/mixed; boundary=\"NextPart\"\n");
            push(@head, "\n");
            push(@head, "--NextPart\n");
            push(@head, "Content-Type: text/plain; charset=\"UTF-8\"\n");
            push(@head, "Content-Transfer-Encoding: base64\n\n");

            my @body;
            push(@body, "Ваш пароль от VPN устареет через $i дней. Пожалуйста, смените пароль, как это описано на странице http://some.example.ru/ По всем вопросам можете обращаться по e-mail adm\@example.ru");
            
            my $command = "$sendmail -t $email";
            
            if (open(SENDMAIL, "| $command")) {
                print SENDMAIL @head, encode_base64("@body");
                close SENDMAIL
            or warn "$0: error in closing `$command' for writing: $!\n";
            }
            else { warn "$0: cannot open `| $command' for writing: $!\n"; }
    }
}

$sth->finish;
$dbh->disconnect;
