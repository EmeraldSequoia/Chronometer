#!/usr/bin/perl -w

use strict;

# This script is intended to work around issues with invoking system() on simulator, which in turn is used to generate shadow parts in Henry

# NOTE NOTE NOTE NOTE NOTE
# This script opens a security hole while it is running: *Anyone* who can run a process on the machine can also do anything that the
# user running the script can do (because all this script does is read a command from a socket and then execute it).
# So when you are running the script, ensure you are well protected by other measures from anyone you don't trust running processes on
# your machine.
# The script will time out for safety 30 minutes after it receives and exceutes its last command.

use Cwd;
use IO::Socket::INET;

# auto-flush on socket
$| = 1;

my $port = "7890";

# creating a listening socket
my $socket = new IO::Socket::INET(LocalHost => '0.0.0.0',
                                  LocalPort => $port,
                                  Proto     => 'tcp',
                                  Listen    => 5,
                                  Reuse     => 1);
$socket
  or die "Cannot create socket: $!\n";

# Having the input port open indefinitely is a huge security hole.  Automatically shut down on no activity.
my $serverTimeout = $ENV{ES_COMMAND_SERVER_TIMEOUT};
if (not defined $serverTimeout) {
    $serverTimeout = 1800;  # Don't run for more than 30 minutes; having this port open is a huge security hole.
}
print "Inactivity timeout $serverTimeout seconds; override with \${ES_COMMAND_SERVER_TIMEOUT}\n";

print "commandServer waiting for client connection on port $port\n";

my $start = time();
my $overallTimeout = $start + $serverTimeout;

my $scriptsDir = cwd() . "/scripts";

while(time() < $overallTimeout) {
    $overallTimeout = time() + $serverTimeout;
    # waiting for a new client connection
    my $client_socket = $socket->accept();

    # get information about a newly connected client
    my $client_address = $client_socket->peerhost();
    my $client_port = $client_socket->peerport();
    print "commandServer Connection from $client_address:$client_port\n";
    if ($client_address ne "127.0.0.1") {
        print "Connections disallowed from anywhere but localhost\n";
        exit 1;
    }

    # read up to 1024 characters from the connected client
    my $data = "";
    $client_socket->recv($data, 1024);
    $data =~ s/[\r\n]$//go;
    $data =~ s/\$scripts/$scriptsDir/go;
    # chomp($data);
    if ($data =~ /^exit$|^quit$/i) {
        $client_socket->send("commandServer shutting down per client request\n");
        shutdown($client_socket, 1);
        $socket->close();
        print "commandServer shutting down per client request\n";
        exit(0);
    }
    print "commandServer $data\n";
    open PIPE, "$data 2>&1 |"
      or die "commandServer couldn't open pipe: $!\n";
    while (<PIPE>) {
        $client_socket->send($_);
    }
    close PIPE;

    shutdown($client_socket, 1);
}

$socket->close();
