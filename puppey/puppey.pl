#!/usr/bin/perl
use strict;
use warnings;

#TDB Cut these out to settings.pl
my $socketPath = '/tmp/.puppey.sock';
my $logFile = '/tmp/puppey.log';
my $logFH;
my $verbose = 0;

$|=1;
#TBD Split to in-function use
use Puppey;
use Data::Dumper;
use Getopt::Std;

my %opts;
getopts('hmcdsglv', \%opts);
my $opt; my $help = 0; my $client = 0; my $daemon = 0; 
my $get = 0; my $list = 0; my $main = 0; my $socket = 0;
for $opt (keys %opts) {
	$help = 1 if $opt =~ /h/;
	$verbose = 1 if $opt =~ /v/;
	$main = 1 if $opt =~ /m/;
	$daemon = 1 if $opt =~ /d/;
	$socket = 1 if $opt =~ /s/;
	$client = 1 if $opt =~ /c/;
	$list = 1 if $opt =~ /l/;
	$get = 1 if $opt =~ /g/;
	#default { Puppey::usage(); }
}
print "get[$get]\n" if $verbose;
Puppey::usage() if ( ($main + $socket + $client + $list + $get) < 1 );
open $logFH,">>$logFile" || die "Can't open logfile";
select($logFH); 
$| = 1;
select(STDOUT);
Puppey::logSet($logFH);
Puppey::logWrite("BEGIN\n");
Puppey::usage() if ($help);
Puppey::jobsGet() if ($get);
Puppey::daemonize() if ($daemon);
#Puppey::logWrite("after damemonize\n");
Puppey::socketServer($socketPath) if ($socket);
#Puppey::logWrite("after socketListen\n");
Puppey::socketClient($socketPath) if ($client);
Puppey::main() if ($main);
Puppey::jobsList() if ($list);

Puppey::logWrite("END\n");
my $forked = Puppey::forkedGet();
print Dumper $forked;
close($logFH)
