package System2;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use POSIX qw(:sys_wait_h :limits_h);
use Fcntl;
use Carp;

require Exporter;
require AutoLoader;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw( &system2 );
$VERSION = '0.81';

use vars qw/ $debug /;

# set to nonzero for diagnostics.
$debug=0;

#---------------------------------

my @handle = qw(C_OUT C_ERR);
my $sigchld; # previous SIGCHLD handler
my @args;
my %buf = ();
my %fn = ();
my ($rin, $win, $ein) = ('') x 3;
my ($rout, $wout, $eout) = ('') x 3;
my $pid;

#---------------------------------
sub system2
{
  @args = @_;

  # set up handles to talk to forked process
  pipe(P_IN, C_IN) || croak "can't pipe IN: $!";
  pipe(C_OUT, P_OUT) || croak "can't pipe OUT: $!";
  pipe(C_ERR, P_ERR) || croak "can't pipe ERR: $!";

  # prep filehandles.  get file numbers, set to non-blocking.

  no strict 'refs';
  foreach( @handle )
  {
    # set to non-blocking
    my $ret=0;
    fcntl($_, F_GETFL, $ret) || croak "can't fcntl F_GETFL $_";
    $ret |= O_NONBLOCK;
    fcntl($_, F_SETFL, $ret) || croak "can't fcntl F_SETFL $_";

    # prep fd masks for select()
    $fn{$_} = fileno($_);
    vec($rin, $fn{$_}, 1) = 1;
    $buf{$fn{$_}} = '';
  }
  use strict 'refs';

  $debug && carp "forking [@args]";

  # temporarily disable SIGCHLD handler
  $sigchld = (defined $SIG{'CHLD'}) ? $SIG{'CHLD'} : 'DEFAULT';
  $SIG{'CHLD'} = 'DEFAULT';

  $pid = fork();
  croak "can't fork [@args]: $!" unless defined $pid;

  &child if (!$pid); # child
  my @res = &parent; # parent

  $SIG{'CHLD'} = $sigchld; # restore SIGCHLD handler

  @res; # return output from child process
}

#---------------------------------

sub child
{
  $debug && carp "child pid: $$";

  # close unneeded handles, dup as neccesary.
  close C_IN || croak "child: can't close IN: $!";
  close C_OUT || croak "child: can't close OUT: $!";
  close C_ERR || croak "child: can't close ERR: $!";

  open(STDOUT, '>&P_OUT') || croak "child: can't dup STDOUT: $!";
  open(STDERR, '>&P_ERR') || croak "child: can't dup STDERR: $!";

  select C_OUT; $|=1;
  select C_ERR; $|=1;

  # from perldiag(1):
  #  Statement unlikely to be reached
  #      (W) You did an exec() with some statement after it
  #      other than a die().  This is almost always an error,
  #      because exec() never returns unless there was a
  #      failure.  You probably wanted to use system() instead,
  #      which does return.  To suppress this warning, put the
  #      exec() in a block by itself.

  { exec { $args[0] } @args; }

  croak "can't exec [@args]: $!";
}

#---------------------------------

# parent

sub parent
{
  # close unneeded handles
  close P_IN || croak "can't close IN: $!";
  close P_OUT || croak "can't close OUT: $!";
  close P_ERR || croak "can't close ERR: $!";

  my $status = undef; # exit status of child

  # get data from filehandles, append to appropriate buffers.
  my $nfound = 0;
  while ($nfound != -1)
  {
    $nfound = select($rout=$rin, $wout=$win, $eout=$ein, 1.0);
    if ($nfound == -1) { carp "select() said $!\n"; last }

    no strict 'refs';
    foreach( @handle )
    {
      if (vec($rout, $fn{$_}, 1))
      {
        my $read;
        my $len = length($buf{$fn{$_}});
        my $FD = $fn{$_};

        while ($read = sysread ($_, $buf{$FD}, PIPE_BUF, $len))
        {
          if (!defined $read) { carp "read() said $!\n"; last }
          if ($read == 0) { carp "read() said eof\n"; last }
          $len += $read;
          $debug && carp "read $read from $_ (len $len)";
        }
      }
    }
    use strict 'refs';

    # check for dead child

    # pid of exiting child; the waitpid returns -1 if
    # we waitpid again...
    my $child = waitpid($pid, WNOHANG);

    last if ($child == -1); # child already exited
    #next unless $child;     # no stopped or exited children

    # Is it possible for me to have data in a buffer after the
    # child has exited?  Yep...

    $status = $?;
  }

  $? = $status; # exit with child's status

  ($buf{$fn{'C_OUT'}}, $buf{$fn{'C_ERR'}});
}

#---------------------------------
sub exit_status
{
  my $s = shift;

  my $exit_value  = $s >> 8;
  my $signal_num  = $s & 127;
  my $dumped_core = $s & 128;

  ($exit_value, $signal_num, $dumped_core);
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

System2 - like system(), but with STDERR available as well

=head1 SYNOPSIS

  use System2;

  $System2::debug++;

  my ($out, $err) = system2(@args);
  my ($exit_value, $signal_num, $dumped_core) = &System2::exit_status($?);
  
  print "EXIT: exit_value $exit_value signal_num ".
        "$signal_num dumped_core $dumped_core\n";
  
  print "OUT:\n$out";
  print "ERR:\n$err"

=head1 DESCRIPTION

Execute a command, and returns output from STDOUT and STDERR.  Much
like system().  $? is set.  (Much cheaper than using open3() to
get the same info.)

If $debug is set, on-the fly diagnostics will be reported about
how much data is being read.

Provides for convienence, a routine exit_status() to break out the
exit value into:

  - the exit value of the subprocess
  - which signal, if any, the process died from
  - reports whether there was a core dump.

All right from perlvar(1), so no surprises.

=head1 CAVEATS

Although I've been using this module for literally years now
personally, consider it lightly tested, until I get feedback from
the public at large.

Have at it.

=head1 AUTHOR

Brian Reichert <reichert@numachi.com>

=head1 SEE ALSO

perlfunc(1), perlvar(1).

=cut
