# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use System2;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

if (0)
{
  print "testing $System2::VERSION\n";
  $System2::debug++;
  print "debug is $System2::debug\n";
}

my @args = './test_foo.pl';
my ($out, $err) = system2(@args);
my ($exit_value, $signal_num, $dumped_core) = &System2::exit_status($?);

#print "exit: $?\n";

#print "(exit_value, signal_num, dumped_core) = ($exit_value, $signal_num, $dumped_core)\n";

if ( ( $exit_value == 4) &&
     ( $out eq 'data to STDOUT' ) &&
     ( $err eq 'data to STDERR' )
   )
{ print "ok 2\n"; } else
{ print "not ok 2\n"; }
