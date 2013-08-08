package Puppey;
my $httpHost = "127.0.0.1:8000";
my $clientID = "2";
my $sqliteFile = "/tmp/agent.db";
my $bucket="";
my $logfile = "puppey.log"; # Convert to Syslog
my $verbose = 0;
my $DBG = scalar(\*STDOUT);

use strict;
use Switch;
#use Storable qw(store retrieve);
#use Socket;
#use YAML;
use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use HTTP::Tiny;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use POSIX;
use Data::Dumper;
use DBI;
use JSON;
use IPC::Open3;
use Symbol qw(gensym);
use IO::File;

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
	Puppey::jobsGet();
	#die "No data file at bucket/Puppey.jobs" unless retrieve("bucket/Puppey.jobs");
	my $count;
	while (1) { 
		Puppey::jobsGet();
		Puppey::logWrite("$$ running a loop, ". $count++. "\n",2);
		my $jobs=Puppey::dbSelectJobs();
		#my $jobs = retrieve("$bucket/Puppey.jobs"); #TBD: to function
		print Dumper $jobs;
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
					Puppey::logWrite 
					   "Error: $key (status " . $jobs->{$key} .")\n";
				}
			}
		} 
		sleep 60;
	}
	close $logFH;
}

sub dbConnect {
	my $dbh = DBI->connect("dbi:SQLite:dbname=$sqliteFile","","");
	return $dbh;
}
sub dbSelectJobs { 
	my $id=shift || undef;
	my $dbh = Puppey::dbConnect;
	my $selectQuery = "SELECT * FROM jobQueue";
	$selectQuery .= " WHERE id = '$id'" if defined $id;
	my $sth = $dbh->prepare($selectQuery);
	my $rv = $sth->execute;
	my $data = $sth->fetchall_hashref('id');
	$dbh->disconnect;
	return $data;
}
sub dbUpdateJobStatus {
	my $job=shift || return -1;
	my $dbh = Puppey::dbConnect;
	my $jobStatus=-1;
	if ($job->{es} == 0) {
		$jobStatus = 'done';
	} else { 
		$jobStatus = 'err';
	}
	
	my $updateQuery = 
		"UPDATE jobQueue SET status='".$jobStatus."' WHERE id=".$job->{id}.";"; 
	print "$updateQuery\n";
	my $sth = $dbh->prepare($updateQuery);
	my $rv = $sth->execute;
	$dbh->disconnect;
	return $rv;
}
sub dbUpdateJobOutput {
	my $job=shift || return -1;
	my $dbh = Puppey::dbConnect;
	for my $key ('stdout','stderr') { 
		chomp $job->{$key};
		$job->{$key} =~ s/  */ /g;
		$job->{$key} =~ s/^\s//g;
	}
	my $updateQuery = "INSERT OR REPLACE INTO jobOutput (id,stdout,stderr,es) values(" 
				.$job->{id}.",'".$job->{stdout}."','"
				.$job->{stderr}."',".$job->{es}.");";
	print "$updateQuery\n";
	my $sth = $dbh->prepare($updateQuery);
	my $rv = $sth->execute;
	$dbh->disconnect;
	return $rv;
}
	
sub dbPrep {
	my $dbh = Puppey::dbConnect;
	my $createQuery="CREATE TABLE IF NOT EXISTS jobOutput
			(id INT PRIMARY KEY ASC, stdout VARCHAR(5000),
			stderr VARCHAR(5000), es INT);";
	Puppey::logWrite("$createQuery\n",2);
	my $rv=$dbh->do($createQuery);
	$createQuery="CREATE TABLE IF NOT EXISTS jobQueue
			(id INT PRIMARY KEY ASC, exe VARCHAR(500),
			stdin VARCHAR(5000), status VARCHAR(10));";
	Puppey::logWrite("$createQuery\n",2);
	$rv=$dbh->do($createQuery);
	$dbh->disconnect();
	return $rv;
}
sub dbInsertJob {
	Puppey::dbPrep;
	my $id = shift;
	my $exe = shift;
	my $stdin = shift || '';
	
	my $dbh = Puppey::dbConnect;
	my $insQuery="INSERT INTO jobQueue (id,exe,stdin,status) values('$id','$exe','$stdin','new')";
	Puppey::logWrite("$insQuery\n",2);
	my $sth = $dbh->prepare($insQuery);
	my $rv = $sth->execute;
	$dbh->disconnect;
	return $rv;
}
sub jobsGet {
	my $data = {};
	#-#$data = HTTP::Tiny->new->get("http://$httpHost/dug/jobs/$clientID");
	#-#for my $key (keys %$data) { 
	#-#	Puppey::logWrite("jobGet $key ->" . $data->{$key} . "\n",2) unless $key eq "content";
	#-#}
	#-#Puppey::logWrite("jobGet content: " . $data->{'content'}) if $verbose > 1;
	$data->{'content'} = '{
		"001":{"id":"001","exe":"uname -a","stdin":""},
		"002":{"id":"002","exe":"uptime","stdin":""},
		"003":{"id":"003","exe":"du -chs /tmp | grep tmp","stdin":""},
		"004":{"id":"004","exe":"ls -l /tmp /tmpa/","stdin":""}
	}';
	my $jobs = eval {
		decode_json($data->{'content'});
	} or do {
		my $e = $@;
		Puppey::logWrite("jobGet failed at Load(\$data->{content}\n$e\n",2);
		die "Can't read JSON from $httpHost\n";
	};
	for my $key (keys %$jobs) { 
		Puppey::logWrite("jobGet \$jobs $key->".$jobs->{$key}."\n",2);
		Puppey::dbInsertJob(
				$jobs->{$key}{id},
				$jobs->{$key}{exe},
				$jobs->{$key}{stdin});
	}
}
sub jobsList {
	my $data = Puppey::dbSelectJobs;
	#print Dumper $data;
	for my $key (keys %$data) { 
		Puppey::logWrite("jobList $key ->" . $data->{$key} . "\n");
	}
	return 1;
}
sub jobExec {
	my $job = shift;
	return -1 unless (defined $job->{'exe'});
	Puppey::logWrite("jobExec processing jobID: ". $job->{'id'}."\n",2); 
	my $pid = fork ();
	#use Symbol 'gensym'; $err = gensym;
	if ($pid < 0) {
		die "fork failed";
	} elsif ($pid) {
		Puppey::logWrite("jobExec fork pid: $pid\n",2);
		$forked->{$pid}=1;
	} else {
		my $cmd = defined $job->{'shell'} ? 
			$job->{'shell'} . " '" . $job->{'command'}."'" : $job->{'exe'} ;
		Puppey::logWrite("running $cmd and updating \$job\n",2);
		local *CATCHOUT = IO::File->new_tmpfile;
		local *CATCHERR = IO::File->new_tmpfile;
		my $jPid = open3(gensym, ">&CATCHOUT", ">&CATCHERR", $cmd);
		waitpid($jPid, 0);
		$job->{es} = $? >> 8;
		seek $_, 0, 0 for \*CATCHOUT, \*CATCHERR;
		$job->{stdout} = join "\n", <CATCHOUT>;
		$job->{stderr} = join "\n", <CATCHERR>;
		chomp $job->{stdout} ; chomp $job->{stderr};
		#Puppey::logWrite("\$job->{'stdout'} = ".$job->{'stdout'}."\n",2);
		Puppey::dbUpdateJobOutput($job);
		Puppey::dbUpdateJobStatus($job);
		chdir "/";
		umask 0;
		exit $job->{es};
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
