#!/usr/bin/perl
my $info = <<INFO;
OCSP Sweeper 1.1
This program will open an ocsp fifo and parse it every N seconds and trigger a send_nsca event at X bytes
Written by Adam Douglass and Jason Lancaster
Last modified 6/08/03 by Jason Lancaster <jlancaster+ocsp@gmail.com>

Usage: $0 -f <log_file> -H <host_address> [-n nsca_location] [-c nsca_cfg] [-t time] [-l limit] [-d]

Options:
<log_file>\t= Log file to read
<host_address>\t= Host to send data to
[nsca_location] = Location to send_nsca binary
\t\t  (default /usr/local/nagios/bin/send_nsca)
[nsca_cfg]\t= Location to send_nsca.cfg
\t\t  (default /usr/local/nagios/etc/send_nsca.cfg)
[time]\t\t= Time between each read of log file
\t\t  (default frequency is 5 seconds)
[limit]\t\t= Length limit to split nsca connections at (In case of fifo buffer limit)
\t\t  (default is 5120 bytes)
[d]\t\t= Debug mode
[h]\t\t= Print this help file

INFO

use strict;
use Getopt::Std;
use POSIX ":sys_wait_h";      # signal and waitpid routines

my (%arg);
# Define options
getopts("dht:f:H:l:n:c:", \%arg);

# Set option defaults
$arg{d} = 0 unless $arg{d};
$arg{h} = 0 unless $arg{h};
$arg{t} = 3 unless $arg{t};
$arg{l} = 4096 unless $arg{l};
$arg{n} = "/usr/local/nagios/bin/send_nsca" unless $arg{n};
$arg{c} = "/usr/local/nagios/etc/send_nsca.cfg" unless $arg{c};

# Do some basic option handling and set requirements
if ($arg{h} == 1) { &helpit; }
unless ($arg{f}) { warn "Missing required option -f <log_file>\n\n"; &helpit; }
unless ($arg{H}) { warn "Missing required option -H <host_name>\n\n"; &helpit; }

my ($childpid, $pidfile);

sub debugit {
    my ($msg) = @_;

    if ($arg{d}) {
        printf "# DEBUG (%d)# %s\n", $$, $msg;
    }
}

sub helpit {
    print $info;

    exit 0;
}

sub log_watcher {                                                                       # log_watcher BEGIN
    open(LOG, "<$arg{f}") || die "Error opening log file $!";
    #while (<LOG>) { 1; } # Skip to the end of the log file... not used because we're using a fifo
    while (1) {
        sleep $arg{t};
        &debugit("Scanning log...");
        seek(LOG,0,1);
        my ($str) = ();
        while (<LOG>) {
            if (length($str . $_) >= $arg{l}) {
                &spawn_daemon($str);
                $str = '';
            }

            $str .= $_;
        }

        if ($str ne '') { &spawn_daemon($str); }
        &debugit("Finished loop, doing cleanup.\n");

    }
    close(LOG);
}

sub spawn_daemon {                                                                      # spawn_daemon BEGIN
    my ($nsca_str) = @_;

    foreach ('CHLD', 'TERM', 'HUP', 'KILL', 'QUIT') { $SIG{$_} = 'IGNORE'; }
    my $ppid = $$;
    if (($childpid=fork)) {       # in parent
        &debugit("Forked spawn_daemon pid $childpid");
        return 1;
    }
    # here is the child process
    $0 = "$0 (spawn_daemon parent=$ppid)" ;      # change process name

    &debugit(sprintf("send_nsca processing string with size of %d", length($nsca_str)));

    open(NSCA, "|$arg{n} -H $arg{H} -to 60 -c $arg{c}")
        || &debugit("ERROR!! Can not open $arg{n} $!");
    print NSCA $nsca_str;
    close(NSCA);

    &debugit("send_nsca processing complete. Terminating.");

    exit 0;
}                                                                                       # spawn_daemon END

sub init_reaper {
    my ($zombie);
    while (($zombie = waitpid(-1, &WNOHANG)) != -1) {
    }
    &debugit(sprintf("Killed zombie pid %d", $zombie));

    return 0;
}

sub main {                                                                              # main BEGIN
    # Process arguments, optionally (by default) fork to the BG...
    # and watch the log file specified

    # Error checking...
    if (!-r $arg{f}) { printf "ERROR! Can not open/read logfile %s. Please check the file and try again.\n", $arg{f}; exit 1; }

    if ($arg{d}) {
        print "## DEBUGGING OUTPUT ##\n";
        printf "Logfile: %s\n", $arg{f};
        printf "Frequency: %s seconds\n", $arg{t};
        printf "Limit: %d chars\n", $arg{l};
    }

    &log_watcher();
}                                                                                       # main END


&main();
