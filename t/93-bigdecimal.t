#!/usr/bin/perl
#
# 2011-01-31 stefan(s.bv.) Created new test:
# Playing with very big | small numbers
# Smallest and biggest decimal supported by Firebird:
#   -922337203685477.5808, 922337203685477.5807
#
# Look at bigdecimal_read.t for a variant that uses plain do() without
# parameters for the insertion of the values.
#

use strict;
use warnings;

use Math::BigFloat try => 'GMP';
use Test::More;
use DBI;

use lib 't','.';

use TestFirebird;
my $T = TestFirebird->new;

my ($dbh, $error_str) = $T->connect_to_database();

if ($error_str) {
    BAIL_OUT("Unknown: $error_str!");
}

unless ( $dbh->isa('DBI::db') ) {
    plan skip_all => 'Connection to database failed, cannot continue testing';
}
else {
    plan tests => 21;
}

ok($dbh, 'Connected to the database');

# ------- TESTS ------------------------------------------------------------- #

# Find a new table name
my $table = find_new_table($dbh);
ok($table, "TABLE is '$table'");

# Create a new table
my $def =<<"DEF";
CREATE TABLE $table (
    DEC_MIN  DECIMAL(18,4),
    DEC_MAX  DECIMAL(18,4)
)
DEF
ok( $dbh->do($def), qq{CREATE TABLE '$table'} );

# Expected fetched values
my @correct = (
    [ '-922337203685477.5808', '922337203685477.5807' ],
    [ '-0.3', '0.3' ],
    [ '-0.6', '0.6' ],
    [ '-0.5', '0.5' ],
);

# Insert some values
my $stmt =<<"END_OF_QUERY";
INSERT INTO $table ( DEC_MIN, DEC_MAX)
VALUES (?, ?)
END_OF_QUERY

ok(my $insert = $dbh->prepare($stmt), 'PREPARE INSERT');

ok( $insert->execute(@$_), "INSERT '$_->[0]', '$_->[1]'" ) for @correct;

# Select the values
ok( my $cursor = $dbh->prepare( qq{SELECT * FROM $table} ), 'PREPARE SELECT' );

ok($cursor->execute, 'EXECUTE SELECT');

ok((my $res = $cursor->fetchall_arrayref), 'FETCHALL');

my ($types, $names, $fields) = @{$cursor}{qw(TYPE NAME NUM_OF_FIELDS)};

for (my $i = 0; $i < @$res; $i++) {
    for (my $j = 0; $j < $fields; $j++) {
        my $result  = qq{$res->[$i][$j]};
        my $mresult = Math::BigFloat->new($result);

        my $corect  = $correct[$i][$j];
        my $mcorect = Math::BigFloat->new($corect);

        is($mresult, $mcorect, "Field: $names->[$j]");
        # diag "got: $mresult";
        # diag "exp: $mcorect";
    }
}

# Drop the test table
$dbh->{AutoCommit} = 1;

ok( $dbh->do("DROP TABLE $table"), "DROP TABLE '$table'" );

# Finally disconnect.
ok($dbh->disconnect(), 'DISCONNECT');
