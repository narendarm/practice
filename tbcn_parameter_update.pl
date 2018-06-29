#!perl.exe -w
use strict;
use warnings;
use DBI;
use DBD::Oracle;
use File::Basename;
use Getopt::Long;
#***************************************************************************************
# File Name:  tbcn_parameter_update.pl
# Language:   Perl
# Copyright:  (c) 2005 SBC - All Rights Reserved.
# 
# Purpose:    This script is responsible for examining and updating the tbcn_parameter table for OMS.
#
# =============================================================================
#
# Database Table(s)/Schema(s): lsoms - multiple
#
# Modification Log:
#
# Date         Author    Explanation
# =============================================================================

#***************************************************************************************
$ENV{'NLS_LANG'}=  "AMERICAN_AMERICA.AL32UTF8" ;
my %Config;
#my $host='pida2904.pedc.sbc.com'; #RD1
#my $host='pida206.pedc.sbc.com';  #ETS
#my $host='cidc1706.sldc.sbc.com'; #DEV1
#my $host='cidc2707.sldc.sbc.com'; #DEV2
my $host='cidc2705.sldc.sbc.com'; #SAT
#my $host='cipc2603.sldc.sbc.com'; #PRD
my $sid='lsomst01'; #Required
my $passwd='db50lsoms'; #Required
my $user='sat1e_codeown'; #Required
my $old_build_dir='sat1d'; #Required
my $new_build_dir='rd1a';#Required
my $counter=0;
my $select_sql=q{SELECT rowid, a.obtain_value from tbcn_parameter a where a.obtain_value like '%file:%'};
my $update_sql=q{ UPDATE tbcn_parameter a SET a.obtain_value = ? WHERE rowid = ?};
#use with two parameters - 1=revised obtain_value text, 2=function_id.
logme("Script execution started");

$ENV{'ORACLE_HOME'}= 'c:\oracle\ora92';
$ENV{LD_LIBRARY_PATH} = "$ENV{ORACLE_HOME}/lib";
#connect to the database...
my $dbh = DBI->connect( "dbi:Oracle:host=$host;sid=$sid", $user, $passwd)
                                    || die "Database connection not made: $DBI::errstr";

#Begin DBI processing
    my $sth1 = $dbh->prepare( "$select_sql" );
	my $sth2 = $dbh->prepare( $update_sql );
    $sth1->execute();
	my ($rowid, $obtain_value);
	$sth1->bind_columns(\($rowid, $obtain_value));
    while ($sth1->fetch) {
		next unless ($obtain_value=~m|file:|);
	logme("IN: $rowid : $obtain_value");
		$obtain_value=~s|($old_build_dir)|$new_build_dir|;
	logme("OUT: $rowid : $obtain_value");
	$sth2->execute($obtain_value, $rowid);
	#sleep(3);
	$counter++;
        }
$sth1->finish();
$sth2->finish();
#Cleanup
$dbh->disconnect();
logme("Execution Complete - $counter processed");
#close(LOG);


sub configuration
{

    Getopt::Long::Configure( "prefix_pattern=(-|\/)" );
    my $Result = GetOptions( \%Config,
                      qw(
                        cur_dir|d=s			
			help|?|h
                      ) );
    $Config{help} = 1 if( ! $Result || scalar @ARGV );

    if( $Config{help} )
	{
	    Syntax();
	    exit();
	}	
    #flip our slashes from DOS to Unix format, if entered in DOS format at the commandline.
    foreach my $key (keys(%Config))
	{
	    $Config{$key} =~ s!\\!/!g;
	}
}#end Configuration sub


#Write current time to the log file
sub logme {
    my @lt = localtime(time);
    my $lt=localtime();
    my $timestamp = sprintf "%4d%02d%02d%02d%02d%02d", $lt[
    +5]+1900, $lt[4]+1, @lt[3,2,1,0] ;
    my $shortstamp=sprintf "%4d%02d",$lt[5]+1900,$lt[4]+1;
    my $logfile="tbcn_parameter_update_$shortstamp.LOG";
open (LOG,">>$logfile") or die "Could not open log file\n";
print LOG "$lt :: @_\n";
print "$lt :: @_ :: $counter\n";
close LOG;
}

