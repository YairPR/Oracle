#!/usr/bin/perl
# dbi.pl

print "Hi I am the perl script\n";

use DBI;
use warnings;
use strict;

# RDS instance info
my $RDS_PORT=$ARGV[0];
my $RDS_HOST=$ARGV[1];
my $RDS_LOGIN=$ARGV[2];
my $RDS_SID=$ARGV[3];

# print for @INC;
# print $RDS_PORT."\n";
# print $RDS_HOST."\n";
# print $RDS_LOGIN."\n";
# print $RDS_SID."\n";

# Oracle destination directory and file name
#The $ARGV[0] is a parameter you pass into the script
my $dirname = "DATA_PUMP_DIR";
my $fname = $ARGV[4];
# print $fname."\n";

my $data = "dummy";
my $chunk = 8192;

my $sql_open = "BEGIN perl_global.fh := utl_file.fopen(:dirname, :fname, 'wb', :chunk); END;";
my $sql_write = "BEGIN utl_file.put_raw(perl_global.fh, :data, true); END;";
my $sql_close = "BEGIN utl_file.fclose(perl_global.fh); END;";
my $sql_global = "create or replace package perl_global as fh utl_file.file_type; end;";

print "before connetc";

my $conn = DBI->connect('dbi:Oracle:host='.$RDS_HOST.';sid='.$RDS_SID.';port='.$RDS_PORT,$RDS_LOGIN, '') || die ( $DBI::errstr . "\n");

print "after connetc";

# create a package just to have a global variable
my $updated=$conn->do($sql_global);
# open the file for writing
my $stmt = $conn->prepare ($sql_open);
$stmt->bind_param_inout(":dirname", \$dirname, 12);
$stmt->bind_param_inout(":fname", \$fname, 12);
$stmt->bind_param_inout(":chunk", \$chunk, 4);
$stmt->execute() || die ( $DBI::errstr . "\n");

open (INF, $fname) || die "\nCan't open $fname for reading: $!\n";
binmode(INF);
$stmt = $conn->prepare ($sql_write);
my %attrib = ('ora_type','24');
my $val=1;
while ($val> 0) {
  $val = read (INF, $data, $chunk);
  $stmt->bind_param(":data", $data , \%attrib);
  $stmt->execute() || die ( $DBI::errstr . "\n") ; };
die "Problem copying: $!\n" if $!;

close INF || die "Can't close $fname: $!\n";

$stmt = $conn->prepare ($sql_close);
$stmt->execute() || die ( $DBI::errstr . "\n") ;
