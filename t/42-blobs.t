#!/usr/local/bin/perl
#
#
#   This is a test for correct handling of BLOBS; namely $dbh->quote
#   is expected to work correctly.
#

# 2011-01-29 stefansbv
# New version based on t/testlib.pl and Firebird.dbtest

use strict;
use warnings;

use Test::More;
use Test::Exception;
use DBI qw(:sql_types);

use lib 't','.';

use TestFirebird;
my $T = TestFirebird->new;

my ( $dbh, $error_str ) =
  $T->connect_to_database( { ChopBlanks => 1, LongReadLen => 524288, } );

if ($error_str) {
    BAIL_OUT("Unknown: $error_str!");
}

unless ( $dbh->isa('DBI::db') ) {
    plan skip_all => 'Connection to database failed, cannot continue testing';
}

ok($dbh, 'Connected to the database');

# ------- TESTS ------------------------------------------------------------- #

#
#   Find a possible new table name
#
my $table = find_new_table($dbh);
#diag $table;
ok($table);

my $def = qq{
CREATE TABLE $table (
id   INTEGER NOT NULL PRIMARY KEY,
name BLOB
)
};

# Repeat test?
foreach my $size ( 1 .. 5 ) {

    #
    #   Create a new table
    #
    ok( $dbh->do($def), qq{CREATE TABLE '$table'} );

    $dbh->{AutoCommit} = 0;

    #
    #  Create a blob
    #
    my $blob = q{};    # Empty

    my $b = "";
    for ( my $j = 0 ; $j < 256 ; $j++ ) {
        $b .= chr($j);
    }

    $blob = $b x $size;

    #
    #   Insert a row into the test table.......
    #
    my ($query);

    my $sql_insert = "INSERT INTO $table VALUES(?, ?)";

    # if ($ENV{'SHOW_BLOBS'}  &&  open(OUT, ">" . $ENV{'SHOW_BLOBS'})) {
    #     print OUT $query;
    #     close(OUT);
    # }

    ok( my $cursor = $dbh->prepare($sql_insert), 'PREPARE INSERT blobs' );

    # Insert 10 rows
    for ( my $i = 0 ; $i < 10 ; $i++ ) {
        ok( $cursor->execute( $i, $blob ), "EXECUTE INSERT row $i" );
    }

    #
    #   Now, try SELECT'ing the row out.
    #

    my $sql_sele = qq{SELECT * FROM $table WHERE id < 10 ORDER BY id};
    ok( my $cursor2 = $dbh->prepare($sql_sele), 'PREPARE SELECT blobs' );

    ok( $cursor2->execute(), "EXECUTE SELECT blobs" );

    for ( my $i = 0 ; $i < 10 ; $i++ ) {
        ok( ( my $row = $cursor2->fetchrow_arrayref ), 'FETCHROW' );

        is( $$row[0], $i,    'ID matches' );
        is( $$row[1], $blob, 'BLOB matches' );

        # Some supplementary inserts
        if ( $i >= 5 ) {
            my $id = $i + 10;
            ok( $cursor->execute( $id, $blob ), "EXECUTE INSERT $id" );
        }
    }

    ok( $cursor2->finish );
    ok( $cursor->finish );

    #
    #   Finally drop the test table.
    #
    $dbh->{AutoCommit} = 1;

    ok( $dbh->do("DROP TABLE $table"), "DROP TABLE '$table'" );

}                                            # repeat test

ok( $dbh->do($def), qq{CREATE TABLE '$table'} );
my $random_bin = '';
$random_bin .= chr(int(rand(256))) for 1..600_000;

ok( $dbh->do( "INSERT into $table values(?, ?)", undef, 42, $random_bin ),
    "insert blog larger than LongReadLen" );

throws_ok { $dbh->selectall_arrayref("select * from $table WHERE id = 42") }
qr/Not enough LongReadLen buffer/,
    "Fetching a BLOB larger than LongReadLen throws";

#- end test
done_testing();
