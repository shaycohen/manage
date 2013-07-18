package Puppey;
my $httpHost = "127.0.0.1:8000";
my $clientID = "1";
my $bucket = "/dev/shm";
my $logfile = "puppey.log";
my $verbose = 0;
my $DBG = scalar(\*STDOUT);

use strict;
use Switch;
use Storable qw(store retrieve);
#use Socket;
use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use HTTP::Tiny;
use YAML;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use POSIX;
use Data::Dumper;
$VERSION     = 0.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(socketServer daemonize usage socketClient logWrite logSet);
%EXPORT_TAGS = ( DEFAULT => [qw(&usage)] );
#
our $logFH;
our $forked = {};

sub daemonize () {
	my $pid = fork ();
	if ($pid < 0) {
		die "fork failed";
	} elsif ($pid) {
		Puppey::logWrite("daemon pid: $pid\n");
		$forked->{$pid}=1;
		exit 0;
	} else {
		Puppey::logWrite("class daemonize\n");
		chdir "/";
		umask 0;
		#foreach (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024))
		#	{ POSIX::close $_ }
		open (STDIN, "</dev/null");
		open (STDOUT, ">/dev/null");
		open (STDERR, ">&STDOUT");
	}
}

sub forkedGet {
	return $forked;
}
sub logSet {
	$logFH = shift;
	return 1;
}
sub logWrite {
	my $msg = shift;
	my $status = shift;
	print $DBG "$$ $msg" if $status > 1;
	print $logFH "$$ $msg";
	return 1;
}


sub main { 
	die "No data file at $bucket/Puppey.jobs" unless retrieve("$bucket/Puppey.jobs");
	my $count;
	while (1) { 
		Puppey::jobsGet();
		Puppey::logWrite("$$ running a loop, ". $count++. "\n",2);
		my $jobs = retrieve("$bucket/Puppey.jobs"); #TBD: to function
		#print Dumper $jobs;
		for my $key (keys %{$jobs}) { 
			Puppey::logWrite("main processing jobID: ". $key. "\n",2);
			switch ($jobs->{$key}{'status'}) { 
				case 'new' {
					Puppey::logWrite "exec: $key\n",2;
					Puppey::jobExec( $jobs->{$key} );
				} case 'disp' {
					Puppey::logWrite "monitor: $key\n",2;
				} case 'done' {
					Puppey::logWrite "archive: $key\n",2;
				} case 'err' { 
					Puppey::logWrite "handle: $key\n",2;
				} else { 
					Puppey::logWrite "Error: $key (status " . $jobs->{$key} .")\n";
				}
			}
		} 
		sleep 60;
	}
	close $logFH;
}

sub jobsGet {
	my $data = {};
	$data = HTTP::Tiny->new->get("http://$httpHost/dug/jobs/$clientID");
	for my $key (keys %$data) { 
		Puppey::logWrite("jobGet $key ->" . $data->{$key} . "\n",2) unless $key eq "content";
	}
	Puppey::logWrite("jobGet content: " . $data->{'content'}) if $verbose > 1;
	#print $DBG "jobGet \$data->{'content'}:". $data->{'content'} . "\n";
	#$data->{'content'} =~ s/\&//g; #!!!DONT ENABLE THIS!!! Temper with YAML feed to test eval or do
	my $jobs = eval {
		Load($data->{'content'});
		#1;
	} or do {
		my $e = $@;
		Puppey::logWrite("jobGet failed at Load(\$data->{content}\n$e\n",2);
	};

	for my $key (keys %$jobs) { 
		Puppey::logWrite("jobGet \$jobs $key ->" . $jobs->{$key} . "\n",2);
		#print Dumper $jobs->{$key};
	}
	store $jobs, "$bucket/Puppey.jobs";
	return $jobs;
}

sub jobsList {
	my $data = retrieve("$bucket/Puppey.jobs");
	print Dumper $data;
	for my $key (keys %$data) { 
		Puppey::logWrite("jobList $key ->" . $data->{$key} . "\n");
	}
	return 1;
}
sub jobExec {
	my $job = shift;
	return -1 unless (defined $job->{'exec'});
	Puppey::logWrite("jobExec processing jobID: ". $job->{'id'}."\n",2); 
	my $cmd = defined $job->{'shell'} ? $job->{'shell'} . " '" . $job->{'command'}."'" : $job->{'exec'} ;
	my $pid = fork ();
	if ($pid < 0) {
		die "fork failed";
	} elsif ($pid) {
		Puppey::logWrite("jobExec fork pid: $pid\n",2);
		$forked->{$pid}=1;
	} else {
		my $es=0;
		Puppey::logWrite("running $cmd and updating \$job\n",2);
		if (open EXEC, "$cmd|") { 
			$job->{'output'} = join("\n", <EXEC>);
		} else { 
			$job->{'output'} = $!;
		}
		Puppey::logWrite("\$job->{'output'} = ".$job->{'output'}."\n",2);
		store $job, "$bucket/Puppey.jobStat.".$job->{'id'};
		chdir "/";
		umask 0;
		exit $es;
	}
	Puppey::logWrite("jobExec ended\n");
}

sub socketServer{
	Puppey::logWrite("$$ Started socketServer\n");
	my $socket_path = shift;
	unlink($socket_path);
	my $listner = IO::Socket::UNIX->new(
		Type   => SOCK_STREAM,
		Local  => $socket_path,
		Listen => SOMAXCONN,
	) or die("Can't create server socket: $!\n");
	die "No data file at $bucket/Puppey.jobs" unless retrieve("$bucket/Puppey.jobs");
	while ( my $socket = $listner->accept() or die("Can't accept connection: $!\n")) { 
		my $jobs = retrieve("$bucket/Puppey.jobs");
		chomp( my $line = <$socket> );
		Puppey::logWrite("$$ retrieved " . $jobs->{'count'} . "\n");
		foreach my $key (keys %{$jobs}) { 
			$socket->send($key." ".$jobs->{$key}{'class'}.":\t".$jobs->{$key}->{'name'}.
					"\t".$jobs->{$key}{'schedule'}."(".$jobs->{$key}{'status'}.")\n");
		}
	}
}
sub socketClient {
	print STDERR "class socketClient\n";
	my $socket_path = shift;
	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM,
		Peer => $socket_path,
	)
		or die("Can't connect to server: $!\n");

	print $socket "cmd1\n";
	while ( my $line = <$socket> ) {
		chomp $line;
		print "$line\n";
	}
}

sub usage { 
	print "usage: perl puppey.pl arg ..
	-h help
	-v verbose
	-d deamon
	-s socket
	-d daemon
	-c client
	-l list
	-g get
	-m main
";
	exit(1);
}
1;
