#! /appl/OMS/perl/bin/perl
################################################################################
#
# program    : ICSetup.pl
# date       : 8 Aug 2007
# author     : Dan Fitzpatrick
# description: Reads the ICD xml file and a supporting infra JSX file, and then
#              executes the directives in that file to configure OMS interfaces.
#              OMS interfaces affected by IC setup include WebSphere JMS
#              config, Spring.xml files.
#
################################################################################
# CURRENT VERSION: 4.8.2
################################################################################
# to do list :
################################################################################
#   Phase 1 - Initial Capability and WAS JMS Resource Configuration
################################################################################
# o read command line options
# o read Infra jsx file
# o read Dev jsx file
# o generate JACL to detect existing JMS Provider
# o generate JACL to remove existing JMS Provider
# o generate JACL to create JMS setup
# o execute generated JACL
# o create J2C entries
# o select J2C entries
# o delete option
################################################################################
#   Phase 2 - Queue Validation
################################################################################
# o test queues and QCFs
################################################################################
#   Phase 2.1 - Additional Queue Validation
################################################################################
# o test queues against multiple QCFs
################################################################################
#   Phase 3 - Spring file updates
################################################################################
# o read Spring file
# o verify/update Spring file
################################################################################
#   Phase 3.1 - Built-in logging.
################################################################################
# o log directly to log file and to screen
################################################################################
#   Phase 3.11 - Fixes
################################################################################
# o jndiConnectionFactoryName added to list of service attributes to pass
# o $ICXml must be at least 31 characters (<CONF/><JSX/><PRFX Prefix="*"/>)
# o Do not set wsdl attribs to null if they are not specified in the ICD
# o Check existence of BrowseQueue and die if any component does not exist
################################################################################
#   Phase 4 - APM.XML updates (FUTURE)
################################################################################
# - read apm.xml file
# - verify queues, qcfs, etc in apm.xml
# - verify CCM entries for JMS in apm.xml
# - update apm.xml
################################################################################
#   Phase 5 - Improvements to behavior (FUTURE)
################################################################################
# - separate Connection and Session Pools
################################################################################

no XML::SAX;

use XML::Smart;
use strict;
use DBI;
#use DBD::Oracle;
use Getopt::Long qw (:config no_auto_help prefix_pattern=(-|\/));
use File::Basename;
use File::Copy;
use Term::ReadKey;
use XML::Twig;
use Term::ANSIColor;
################################################################################
# Globals
################################################################################
#  Internal flags to control what is done and what is not done.
my ($ENABLE_DEBUG, $QUIET, $NOSPRING, $NODB, $NOJSX, $NOAPM, $REPORT, $DELETE, $TESTONLY, $NOASP,$NOFBCERT);
my $LOGLEVEL = 7;
#  Pointers to XML, filenames
my ($JSXIxml, $JSXDxml, $ICXml, $JSXIFile, $ICDFile, $jaclFile);
#  Other globals
my ($filePrefix, $envCell, $envClus, $envNode, $envSrvr, $envPfxI, $envPfxD, $dir, $dbh);
my $jsdSet=0;
my $jsiSet=0;
my $pfxSet=0;
my $cfgDir=".";
#### TIBCO ####
#my $defPrvClasspath="/appl/OMS/Software/lib/SonicMQ/sonic_ASPI.jar;/appl/OMS/Software/lib/SonicMQ/sonic_Client.jar;/appl/OMS/Software/lib/SonicMQ/sonic_XA.jar;/appl/OMS/Software/lib/SonicMQ/sonic_SSL.jar;/appl/OMS/Software/lib/SonicMQ/sonic_Crypto.jar;/appl/OMS/Software/lib/SonicMQ/sonic_Selector.jar";
my $defEMBUSPrvClasspath="/appl/OMS/Software/lib/SonicMQ/sonic_ASPI.jar;/appl/OMS/Software/lib/SonicMQ/sonic_Client.jar;/appl/OMS/Software/lib/SonicMQ/sonic_XA.jar;/appl/OMS/Software/lib/SonicMQ/sonic_SSL.jar;/appl/OMS/Software/lib/SonicMQ/sonic_Crypto.jar;/appl/OMS/Software/lib/SonicMQ/sonic_Selector.jar";
my $defTibcoPrvClasspath="/appl/OMS/Software/lib/TIBCO/tibjms.jar";
my $defSolacePrvClasspath="/appl/OMS/Software/lib/SOLACE/sol-jms-7.0.0.63.jar;/appl/OMS/Software/lib/SOLACE/sol-jcsmp-7.0.0.63.jar;/appl/OMS/Software/lib/SOLACE/sol-common-7.0.0.63.jar;/appl/OMS/Software/lib/SOLACE/providerutil.jar;/appl/OMS/Software/lib/SOLACE/fscontext.jar;/appl/OMS/Software/lib/SOLACE/commons-codec-1.6.jar;/appl/OMS/Software/lib/SOLACE/commons-lang-2.2.jar;/appl/OMS/Software/lib/SOLACE/commons-logging-1.1.1.jar;/appl/OMS/Software/lib/SOLACE/j2ee.jar;/appl/OMS/Software/lib/SOLACE/jsr173_api.jar";
#my $defPrvContext="com.sun.jndi.ldap.LdapCtxFactory";
my $defEMBUSPrvContext="com.sun.jndi.ldap.LdapCtxFactory";
my $defTibcoPrvContext="com.tibco.tibjms.naming.TibjmsInitialContextFactory";
my $defSolacePrvContext="com.solacesystems.jndi.SolJNDIInitialContextFactory";
my $AuthAlias_E="";
my $AuthAlias_T="";
my $defTibcoPrvCustProp="";
#my $defTibcoPrvCustProp="com.tibco.tibjms.naming.security_protocol=ssl/com.tibco.tibjms.naming.ssl_enable_verify_host=false/com.tibco.tibjms.naming.ssl_vendor=j2se-default";
my $defPrvCustProp="";
my $defSolacePrvCustProp;
#### FUSION ####
my $defFUSIONPrvClasspath="/appl/OMS/Software/lib/WebsphereMQ/discovery-clt-5.0.3.jar;/appl/OMS/Software/lib/WebsphereMQ/discovery-ctx-5.0.12.jar;/appl/OMS/Software/lib/WebsphereMQ/backport-util-concurrent.jar";
my $defFUSIONPrvContext="com.att.aft.jms.FusionCtxFactory";
################
my @okAttrs = qw(initialContextFactory jndiConnectionFactoryName jndiDestinationName jndiReplyDestinationName destinationStyle);
my $defaultJAddrPath = "/definitions/service/port/jms:address/";
my $sslType="SPECIFIC";
my $sslConf="";
use constant {
        emerg => 0,
        alert => 1,
        crit => 2,
        error => 3,
        warning => 4,
        notice => 5,
        info => 6,
        debug =>7,
};

my @logPfx = qw(
        EMERGENCY ALERT CRITICAL ERROR WARNING NOTICE INFO DEBUG
);

## Fusion Bus ASP
my $aspTextReg="\^[a-zA-Z0-9|=|.|_|/]+\$" ;
my $wsadminResult="0";
###################
## BEGIN SUBROUTINES
sub displayUsage() {
################################################################################
#
# subroutine : displayUsage
# date       : 7 Sept 2007
# author     : Dan Fitzpatrick
# description: Prints the usage message
#
################################################################################
	ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
	print "  ICSetup.pl is a simple command-line utility which will create\n";
	print "    Generic JMS Providers for use with Sonic as well as queue\n";
	print "    connection factories and queue destinations for an OMS\n";
	print "    environment.  \n";
	print "\n";
	print "    ICSetup.pl requires two configuration files, one provided by\n";
	print "    the OMS Infrastructure team and the other provided by the OMS\n";
	print "    development team.  Combined, the two files contain all the\n";
	print "    information required to completely configure JMS for a single\n";
	print "    environment.\n";
	print "\n";
	print "  Usage:\n";
	print "  ICSetup.pl [-d {config file directory}] [-{optional flags}] (-p {config filename prefix}\n";
	print "  ICSetup.pl [-d {config file directory}] [-{optional flags}] -i {infra filename} -v {dev filename}\n";
	print "    *  If the first form is used, the config filenames will be \${PREFIX}I.jsx\n";
	print "       and \${PREFIX}-ICD.xml.\n";
	print "    *  Files should be in the location specified by the optional\n";
	print "       -d argument, or in the current working directory.\n";
	print "    *  Filenames and prefixes may include fully qualified or relative path.\n";
    print "\n";
    print "    * The following optional flags are currently recognized:\n";
    print "      -debug  : turns on an insane amount of output so we can see where the program is failing.\n";
    print "      -log N  : sets log level to N. (-debug sets log level to maximum value of 7.\n";
    print "      -quiet  : causes only terminal messages to be output to the screen.  Does not affect file logging.\n";
    print "      -nospring : disables processing of SpringJMS items in the ICD.  Implies -nodb.\n";
    print "      -noasp  : disables processing of Active Specification\n";
    print "      -nofbcert : disables validating the fusionbus cert";
    print "      -nodb   : disables processing of database updates (CONTRACT elements).\n";
    print "      -nojsx  : disables processing of the JSX element in the ICD.\n";
    print "      -kill | -delete : causes ICSetup to remove the JMS configuration from WebSphere.  No SPRING processing will be done.\n";
	ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


sub getOpts () {
################################################################################
#
# subroutine : getOpts
# date       : 23 February 2008
# author     : Dan Fitzpatrick
# description: Read the command-line options / args
#
################################################################################
    Getopt::Long::Configure( "prefix_pattern=(-|\/)" );
    GetOptions ('jsxdir|d=s'   => \$cfgDir,
            'ifile|i=s'    => sub {shift(@_);$JSXIFile = shift(@_); $jsiSet=1;},
            'prefix|p=s'   => sub {shift(@_);$filePrefix = shift(@_); $pfxSet=1;},
            'vfile|v=s'    => sub {shift(@_);$ICDFile = shift(@_); $jsdSet=1;},
            'log'          => sub {shift(@_);$LOGLEVEL = shift(@_)},
            'debug'        => sub {shift(@_);$ENABLE_DEBUG=1;$LOGLEVEL=7},
            'quiet'        => \$QUIET,
            'nospring'       => \$NOSPRING,
            'nodb'         => \$NODB,
            'nojsx'        => \$NOJSX,
            'noapm'        => \$NOAPM,
            'report'       => \$REPORT,
            'delete|kill'  => \$DELETE,
            'test'         => \$TESTONLY,
            'noasp'        => \$NOASP,
            'nofbcert'     => \$NOFBCERT,  
            'help|h|?'     => sub {displayUsage() && die},
            '<>'           => sub {my $unknownOpt=shift(@_);
                                 ICSLogger(error,0,"\nunrecognized argument ($unknownOpt)");
                                 ICSLogger(error,0,"...... see usage .............................");
                                 displayUsage() && die;});
    #
	if(!$filePrefix) {
		$filePrefix="env";
	}
    unless ($filePrefix) {
        ($filePrefix)=($JSXIFile=~/^(.+)_/) if ($JSXIFile);
    }
    # Set up the logger
    ICSLogSetup();
    ($ENABLE_DEBUG) && debugOpts();

    checkOpts();
	ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
    }


sub checkOpts {
################################################################################
#
# subroutine : checkOpts
# date       : 14 February 2008
# author     : Dan Fitzpatrick
# description: Check the usage
#
#              Logic for validating usage:
#              arg: -v  -i  -p
#              set?  0   0   0   Error - no files and no prefix given
#                    0   1   0   Error - only one file given
#                    1   0   0   Error - only one file given
#                    0   1   1   Error - file AND prefix given
#                    1   0   1   Error - file AND prefix given
#                    1   1   1   Error - files AND prefix given
#                    1   1   0   Ok - files given
#                    0   0   1   Ok - prefix given
#
#              If the files are given, then both files must be given and the
#              prefix is invalid.  If the prefix is given, then the file
#              options are invalid.
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
	($ENABLE_DEBUG) && debugLogic();
	if (($jsdSet + $jsiSet == 0) && $pfxSet == 1) {
		$ICDFile = $cfgDir . "/" . $filePrefix . "-ICD.xml";
		$JSXIFile = $cfgDir . "/" . $filePrefix . "_I.jsx";
	} elsif (($jsdSet + $jsiSet == 2) && $pfxSet == 0) {
		$ICDFile = $cfgDir . "/" . $ICDFile;
		$JSXIFile = $cfgDir . "/" . $JSXIFile;
		# simple form - nothing to do.
	} elsif ($jsdSet + $jsiSet == 1) {
		ICSLogger(error,0,"Only one file name specified.");
		if ($pfxSet == 1) {
			ICSLogger(error,0,"file prefix must not be specified if file names are specified.");
		}
		ICSLogger(error,0,"...... see usage ....................................................");
		displayUsage && die;
	} elsif ($jsdSet + $jsiSet + $pfxSet == 0) {
		ICSLogger(error,0,"No file names or file prefix specified.");
		ICSLogger(error,0,"...... see usage ....................................................");
		displayUsage && die;
	} elsif ($jsdSet + $jsiSet + $pfxSet == 3) {
		ICSLogger(error,0,"file prefix must not be specified if file names are specified.");
		ICSLogger(error,0,"...... see usage ....................................................");
		displayUsage && die;
	} else {
		ICSLogger(crit,0,"\nI'm so confused!  HELP!!");
		displayUsage && die;
	}
	ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


sub debugOpts {
################################################################################
#
# subroutine : debugOpts
# date       : 14 February 2008
# author     : Dan Fitzpatrick
# description: Output debug information about the command-line args
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    ICSLogger(debug,0,"\n..... debug output .....");
    ICSLogger(debug,1,"getOpts() completed.");
    ICSLogger(debug,1,"command line = (${ARGV})");
    ICSLogger(debug,1,"cfgDir = \"${cfgDir}\"");
    ICSLogger(debug,1,"prefix = \"${filePrefix}\"");
    ICSLogger(debug,1,"JSXIFile = \"${JSXIFile}\"");
    ICSLogger(debug,1,"ICDFile = \"${ICDFile}\"");
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

sub debugLogic {
################################################################################
#
# subroutine : debugLogic
# date       : 17 February 2008
# author     : Dan Fitzpatrick
# description: Output debug information about the command-line validation logic
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    ICSLogger(debug,1,"jsd = $jsdSet");
    ICSLogger(debug,1,"jsi = $jsiSet");
    ICSLogger(debug,1,"pfx = $pfxSet");
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


sub getJSX {
################################################################################
#
# subroutine : getJSX
# date       : 14 February 2008
# author     : Dan Fitzpatrick
# description: Read the infra and dev JMSSetup.xml files, confirm that prefixes
#              match.
#
################################################################################
  ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
  if (-f $JSXIFile) {
    ICSLogger(info,0,"Infra JSX File = $JSXIFile");
    if ( ! ($JSXIxml = XML::Smart->new($JSXIFile))) 
    { 
    	ICSLogger(error,0,"Infra JSX file not readable by XML::Smart!");
    	die;
    }
    #
    # Read the values from the infra JSX file...
    #
    #   my $childFilterEnabled = $ApmXml->{EpiApplication}{ServiceList}[0]{Service}('Name','eq','Log'){FieldList}{Field}('Name','eq','ChildFilterEnabled'){PropertyValueList}{PropertyValue}('PropertyName','eq','ChildFilterEnabled'){Value};
    $envCell = $JSXIxml->{JSX}{CELL}{Name};
$envClus = $JSXIxml->{JSX}{CLUS}{Name};
    $envNode = $JSXIxml->{JSX}{NODE}{Name};
    $envSrvr = $JSXIxml->{JSX}{SRVR}{Name};
    $envPfxI = $JSXIxml->{JSX}{PRFX}{Prefix};
    } else {
      ICSLogger(error,0,"Invalid Infra JSX file specified.\n");
      die;
    }
    
  if (-f $ICDFile) {
    ICSLogger(info,0,"ICD File = $ICDFile");
    # 
    # JSXDxml used to point to the root of the Dev JSX file.  Now, however, it needs to point to the
    # parent element in the file because the file contains siblings to the JSX element.
    #
    # $JSXDxml = XML::Smart->new($ICDFile) || die "ERROR: Dev JSX file not readable by XML::Smart!\n";
    $ICXml = XML::Smart->new($ICDFile);
    if ( length($ICXml->data({nometagen => 1, noheader => 1})) < 31 ) {
    	ICSLogger(error,0,"ICD file not readable by XML::Smart! (" . length($ICXml->data({nometagen => 1, noheader => 1}) . ")") );
    	die;
    }
    $JSXDxml = $ICXml->{CONF};
    # This IF added for backward compatibility.
    if (! $JSXDxml) {
        ICSLogger(info,0,"Old format JSX?");
        if (! ($JSXDxml = $ICXml) ) {
            ICSLogger(error,0,"No valid JSX element found in $ICDFile!");
            die;
        }
    }
    # Read the values from the dev JSX file...
    #
    #   my $childFilterEnabled = $ApmXml->{EpiApplication}{ServiceList}[0]{Service}('Name','eq','Log'){FieldList}{Field}('Name','eq','ChildFilterEnabled'){PropertyValueList}{PropertyValue}('PropertyName','eq','ChildFilterEnabled'){Value};
    $envPfxD = $JSXDxml->{JSX}{PRFX}{Prefix};
    ($ENABLE_DEBUG) && debugJSX();
    if ($envPfxI ne $envPfxD) {
    	ICSLogger(error,0,"Environment prefixes from .jsx files do not match!\n  Dev prefix  =$envPfxD\n  Infra prefix=$envPfxI");
    	die;
        }
    } else {
      ICSLogger(error,0,"Invalid ICD file specified ($ICDFile).");
      ICSLogger(error,0,"Terminating $0!");
      die;
    }
    ICSLogger(info,0,"Done with getJSX.\n");
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

sub validateJSXStructure {
################################################################################
#
# subroutine : validateJSXStructure
# date       : 22 February 2008
# author     : Dan Fitzpatrick
# description: Validate the contents of JSXIxml
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    my $envCell = $JSXIxml->{JSX}{CELL}{Name};
    if ( $envCell eq "" ) {
	    ICSLogger(error,0,"Infra JSX file must specify the cell to operate on.");
	    die;
    }
	my @NodeList = @{$JSXIxml->{JSX}->{NODE}};
	if ( my $nodeCount=@NodeList == 0 ) {
		ICSLogger(error,0,"Infra JSX file must specify at least one node and at least one server per node.");
		die;
	}
	foreach my $node (@NodeList) {
		my @SrvrList = @{$node->{SRVR}};
		if ( my $srvrCount=@SrvrList == 0 ) {
			ICSLogger(error,0,"Infra JSX file must specify at least one server per node.");
			die;
		}
	}
	ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


sub debugJSX {
################################################################################
#
# subroutine : debugJSX
# date       : 14 February 2008
# author     : Dan Fitzpatrick
# description: Debug output regarding jsx files
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
	ICSLogger(debug,2,": Infra JSX: Cell: $envCell");
	ICSLogger(debug,2,": Infra JSX: Node: $envNode");
	ICSLogger(debug,2,": Infra JSX: Srvr: $envSrvr");
	ICSLogger(debug,2,": Infra JSX: Prfx: $envPfxI");
	ICSLogger(debug,2,":   Dev JSX: Prfx: $envPfxD");
	ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

################################################################################
##
## subroutine : getSolaceCustomProperty
## date       : 8 April 2015
## author     : Ravikant Hetamsaria
## description: Parse custom property of Solace provider from ICD
#################################################################################
sub getSolaceCustomProperty
{
        my $JMSProvider=shift(@_);
        my $rck1 = ref($JMSProvider);
        $defSolacePrvCustProp="";
        ($rck1) || die "DANGER!  arg 1 to writeJACLQCF is not a ref!\n";
        my @custompropList=@{$JMSProvider->{SolaceCustomProperty}->{property}};
        foreach my $customprop (@custompropList)
        {
                my $propName=$customprop->{name};
                my $propValue=$customprop->{value};
                $defSolacePrvCustProp=$propName . '=' . $propValue . '/' . $defSolacePrvCustProp;
        }
        chop($defSolacePrvCustProp);
}

################################################################################
#
# subroutine : getServerCount
# date       : 14 August 2011
# author     : Dharmaraju Maganti
# description: get the No of Servers in the jsx file
#
################################################################################
sub getServerCount
{
	my $srvCount=0;
	my @NodeList=@{$JSXIxml->{JSX}->{NODE}};
	foreach my $node (@NodeList) 
	{
	    #print length($node)." : \"$node\"\n"; exit;
	    #print "$node->{Name}" ;
        my @SrvrList = @{$node->{SRVR}};
        foreach my $srvr (@SrvrList)
        {
            $srvCount++;
        }
    }
    return $srvCount ;
}
################################################################################
#
# subroutine : validateTextData
# date       : 14 August 2011
# author     : Dharmaraju Maganti
# description: Validate the Input Text Data againest Regular Expression
#
################################################################################
sub validateTextDataUsingRegExp
{
	my $Data = $_[0];
	my $exp = $_[1];

	if ( $Data =~ m/$exp/ )
	{
	#	print "$Data>true\n";
		return "1" ;
	}
	else
	{
	#	print "$Data>false\n";
		print "FATAL ERROR:  Not a Valid Value :  $Data  \n";
		return "0" ;
	}
}

################################################################################
#
# subroutine : getNodeCount
# date       : 14 August 2011
# author     : Dharmaraju Maganti
# description: get the No of Servers in the jsx file
#
################################################################################
sub getNodeCount
{
	my $nodeCount=0;
	my @NodeList=@{$JSXIxml->{JSX}->{NODE}};
	foreach my $node (@NodeList) 
	{
	    #print length($node)." : \"$node\"\n"; exit;
	    $nodeCount++;
    }
    return $nodeCount ;
}
sub trim($)
{
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
}
sub ssltrim($)
{
	my $string = shift;
        $string =~ s/_ss$//;
        return $string;
}
################################################################################
#
# subroutine : processClusActiveSpec
# date       : 14 August 2011
# author     : Dharmaraju Maganti
# description: Process the ASP part
#
################################################################################
sub processClusActiveSpec 
{
	ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
	#print "Prams : @_" ;
	my $cluster = $JSXIxml->{JSX}->{CLUS}{Name};
	my @activeSpecList=@{$JSXDxml->{ASP}->{ActivationSpec}};
	my @NodeList=@{$JSXIxml->{JSX}->{NODE}};
	#my $sslConfig = "OMSSSLSettings_$envPfxD";
	my $sslConfig = ssltrim("SS_SSLSettings_$envPfxD");
	if (!$DELETE)
	{
		print JSSJACL "puts \"********************************\"\n" ;
		print JSSJACL "getSSLConfigs $sslConfig \$CellName \n";
		print JSSJACL "puts \"********************************\"\n" ;
		 if(!$NOFBCERT)
		{
			#my $fusion="fusion";
	#print JSSJACL "set FustionBusChain [split [\$AdminTask getCertificateChain {-certificateAlias $envPfxD$fusion -keyStoreName oms_truststore}] \"\\n\"] \n";
			#print JSSJACL "set outScript [ getFusionBusCert \$FustionBusChain ]\n";
		#print JSSJACL "set outQ [string index \$outScript [expr [ string length \$outScript ]-2]]\n";
			#print JSSJACL "puts \$outQ\n";
		}
	}

	foreach my $active (@activeSpecList)
     {
     	#print "\n Active Spec : $active->{name}" ;
     	# is ICDT Value
     	      
     	      
     	      
            my $scopesV = $active->{scope} ;
            my @scopes = split(/\|/,"$scopesV");
     			  my $srvCount  = getServerCount(@NodeList);
     			  my $nodeCount = getNodeCount(@NodeList);
     			#print "\nNode Count : $nodeCount\nServer Count : $srvCount\n" ;
			        foreach my $node (@NodeList)
	     			{
	     				#print "\n Node : $node->{Name}" ;
	     				my @serverList=@{$node->{SRVR}} ;
	     				foreach my $server (@serverList)
	     				{
	     					#ICSLogger(debug,2, " Server : $server->{Name}" );
	     					
	     					if(!(validateTextDataUsingRegExp( $active->{jndiName},"$aspTextReg" )==1&&validateTextDataUsingRegExp( $active->{destinationJndiName},"$aspTextReg" )==1&&validateTextDataUsingRegExp( $active->{qmgrName},"$aspTextReg" )==1&&validateTextDataUsingRegExp( $active->{qmgrHostname},"$aspTextReg" )==1&&validateTextDataUsingRegExp( $active->{qmgrPortNumber},"$aspTextReg" )==1&&validateTextDataUsingRegExp( $active->{qmgrSvrconnChannel},"$aspTextReg" )==1&&validateTextDataUsingRegExp( $active->{messageSelector},"\\S*" )==1))
									{
									    print "FATAL ERROR:  Activation Specification Data Values Not Valid";
										  exit;
									}
									if (!$DELETE)
									{
									if(!$NOFBCERT)
									{
										#print JSSJACL "puts [ compareCert \$outQ $active->{destinationJndiName} ]\n" ;
									}
								  }
	     						if(length($server->{Name})<1)
		     					 {
		     					 	print color 'bold yellow';
		     					 	ICSLogger(warning,0,"No Jvms Found for Specified Scope > Pushing to Cluster Level!");
		     					 	print color 'reset';
		     					 	my $scopeID="1";
		     					 	#cell=1,node=2,jvm=3
											if ( !$DELETE )
				     						{	
				     							writeCreateActivationSpecJACL($active,$cluster,$server,$node,$sslConfig,$scopeID);	
				     						}
				     						else
				     						{
				     							writeDeleteActivationSpecJACL($active,$cluster,$server,$node,$scopeID);	
				     						}		     					
		     					 }
		     					else
		     					{
		     						foreach my $scope (@scopes)
	     							{
		     						    my $scopeID="3";
				     					if ( $server->{Name} =~ m/$scope/ )
				     					{
				     						if ( !$DELETE )
				     						{	
				     							writeCreateActivationSpecJACL($active,$cluster,$server,$node,$sslConfig,$scopeID);	
				     						}
				     						else
				     						{
				     							writeDeleteActivationSpecJACL($active,$cluster,$server,$node,$scopeID);	
				     						}
				     					}
		     					    }
		     					}				            	    
	    				}	        
	    			}
	    		
     			
	        
    		#}
            
        
    }
     ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}
sub writeCreateActivationSpecJACL_Nonseg {
	 my $active = $_[0] ;
	 my $cluster = $_[1] ;
	 my $server = $_[2] ;
	 my $node = $_[3] ;
	 my $sslConfig = $_[4] ;
   my $scopeID =$_[5] ;
######################################
# Code to Configure SSL.
######################################     
     $sslConf="-sslConfiguration $sslConfig";
     my $isIcdt = trim($active->{isICDT}) ;
     $sslType="SPECIFIC";
     #print ">>>>>>>>>>>>ICDT : $isIcdt " ;
     	      if (($isIcdt =~ m/^true$/i) && !($isIcdt eq "" ))
     	      {
     	      	#print "Switching Off SSL" ;
     	      	$sslType="NONE";
     	      	$sslConf="";
     	      	 
     	      }
     	      else
     	      {
     	      	$sslType="SPECIFIC";
     	      	$sslConf="-sslConfiguration $sslConfig";
     	      }
######################################
# Code to Read Advanced Properties.
######################################
									my @advancedProps = @{$active->{advancedProperties}{property}};
	     						my $advanPropOut = "" ;
	     						foreach my $advanProp (@advancedProps) 
	     						{
	     							if (!($advanProp->{name} eq "") )
	     							{
	     							#print "\n$advanPropOut -$advanProp->{name} $advanProp \n";
	     							$advanPropOut="$advanPropOut -$advanProp->{name} $advanProp";
	     							}
	     						}	  
	     						$advanPropOut="$advanPropOut " ;
######################################
# Code to Read Custom Properties.
######################################
	 								my @customProps = @{$active->{customProperties}{property}};
	     						my $custOutP = "{ -customProperties{ " ;
	     						foreach my $custProp (@customProps) 
	     						{
	     							$custOutP="$custOutP {$custProp->{name} $custProp}";
	     						}
	     						$custOutP="$custOutP}}" ;
	     						
                    print JSSJACL "puts \"********************************\"\n" ;
		     						print JSSJACL "puts \"Action   : Adding \"\n";
		     						print JSSJACL "puts \"Type     : Activation Specification \"\n";
		     						print JSSJACL "puts \"Property : $active->{name} \"\n";
								print JSSJACL "puts \"Cluster     : $cluster \"\n";
		     						print JSSJACL "puts \"Node     : $node->{Name} \"\n";
		     						print JSSJACL "puts \"Jvm Name : $server->{Name} \"\n";
		     						print JSSJACL "puts \"SSL      : $sslType \"\n";
		     						print JSSJACL "puts \"MODE     : NON-SEGMENT \"\n";
		     						if ( $scopeID == "1" )
		     						{
		     						print JSSJACL "puts \"Scope    : Cluster \"\n";
								print JSSJACL "set ClusName $cluster\n";
		     							print JSSJACL "set out [createupdateActiveSpec $active->{name} [getClusID \$ClusName ] { -name $active->{name} -jndiName $active->{jndiName} -destinationJndiName $active->{destinationJndiName} -destinationType javax.jms.Queue -qmgrName $active->{qmgrName} -qmgrHostname $active->{qmgrHostname} -qmgrPortNumber $active->{qmgrPortNumber} -qmgrSvrconnChannel $active->{qmgrSvrconnChannel} -messageSelector $active->{messageSelector} -sslType $sslType $sslConf -wmqTransportType CLIENT $advanPropOut  } $custOutP ]\n";
		     						}
		     						elsif ($scopeID == "3")
		     						{
		     						print JSSJACL "puts \"Scope    : Jvm \"\n";
		     							print JSSJACL "set out [createupdateActiveSpec $active->{name} [getSrvrID \$cell $node->{Name} $server->{Name} ] { -name $active->{name} -jndiName $active->{jndiName} -destinationJndiName $active->{destinationJndiName} -destinationType javax.jms.Queue -qmgrName $active->{qmgrName} -qmgrHostname $active->{qmgrHostname} -qmgrPortNumber $active->{qmgrPortNumber} -qmgrSvrconnChannel $active->{qmgrSvrconnChannel} -messageSelector $active->{messageSelector} -sslType $sslType $sslConf  -wmqTransportType CLIENT $advanPropOut  } $custOutP ]\n";
		     						}
		     						elsif ($scopeID == "2")
		     						{
		     						print JSSJACL "puts \"Scope    : Node \"\n";
		     							print JSSJACL "set out [createupdateActiveSpec $active->{name} [getNodeID \$cell $node->{Name} ] { -name $active->{name} -jndiName $active->{jndiName} -destinationJndiName $active->{destinationJndiName} -destinationType javax.jms.Queue -qmgrName $active->{qmgrName} -qmgrHostname $active->{qmgrHostname} -qmgrPortNumber $active->{qmgrPortNumber} -qmgrSvrconnChannel $active->{qmgrSvrconnChannel} -messageSelector $active->{messageSelector} -sslType $sslType $sslConf  -wmqTransportType CLIENT $advanPropOut  } $custOutP ]\n";
		     						}
		     					    print JSSJACL "puts \"********************************\"\n" ;
	
}
sub writeCreateActivationSpecJACL_seg {
	 my $active = $_[0] ;
	 my $cluster = $_[1] ;
	 my $server = $_[2] ;
	 my $node = $_[3] ;
	 my $sslConfig = $_[4] ;
   my $scopeID =$_[5] ;
   my $segInst =$_[6] ;
   my $stateV = "";
######################################
# Code to Configure SSL.
######################################     
     $sslConf="-sslConfiguration $sslConfig";
     my $isIcdt = trim($active->{isICDT}) ;
     $sslType="SPECIFIC";
     #print ">>>>>>>>>>>>ICDT : $isIcdt " ;
     	      if (($isIcdt =~ m/^true$/i) && !($isIcdt eq "" ))
     	      {
     	      	#print "Switching Off SSL" ;
     	      	$sslType="NONE";
     	      	$sslConf="";
     	      	 
     	      }
     	      else
     	      {
     	      	$sslType="SPECIFIC";
     	      	$sslConf="-sslConfiguration $sslConfig";
     	      }
######################################
# Code to Read Advanced Properties.
######################################
									my @advancedProps = @{$active->{advancedProperties}{property}};
	     						my $advanPropOut = "" ;
	     										
	     						foreach my $advanProp (@advancedProps) 
	     						{
	     							if (!($advanProp->{name} eq "") )
	     							{
	     							#print "\n$advanPropOut -$advanProp->{name} $advanProp \n";
	     							$advanPropOut="$advanPropOut -$advanProp->{name} $advanProp";
	     							}
	     						}
######################################
# Appending the Segment Advanced  Props to ASP Advanced Props.
######################################
                        my @segAdvancedProps = @{$segInst->{advancedProperties}{property}};
	     									foreach my $segAdvanOutP (@segAdvancedProps) 
	     									{
	     										if (!($segAdvanOutP->{name} eq "") )
	     											{
	     												$advanPropOut="$advanPropOut -$segAdvanOutP->{name} $segAdvanOutP";
	     											}
	     									}
########################################	     						  
	     						$advanPropOut="$advanPropOut " ;
######################################
# Code to Read Custom Properties.
######################################
	 								my @customProps = @{$active->{customProperties}{property}};
	     						my $custOutP = "{ -customProperties{ " ;
	     						foreach my $custProp (@customProps) 
	     						{
	     							if ( $custProp->{name} eq "WAS_EndpointInitialState" )
	     							{
	     								if ( $custProp eq "ACTIVE" )
	     								{
	     									my @segCustomProps = @{$segInst->{customProperties}{property}};
	     									foreach my $segCustOutP (@segCustomProps) 
	     									{
	     										if ( $segCustOutP->{name} eq "WAS_EndpointInitialState" )
	     										{
	     											$custOutP="$custOutP {$custProp->{name} $segCustOutP}";
	     											$stateV=$segCustOutP;
	     										}
	     									}
	     								}
	     								elsif ( $custProp eq "INACTIVE" )
	     								{
	     									$custOutP="$custOutP {$custProp->{name} INACTIVE}";
	     									$stateV="INACTIVE";
	     								}
	     							}
	     							else
	     							{
	     								$custOutP="$custOutP {$custProp->{name} $custProp}";
	     							}
	     						}
######################################
# Appending the Segment Custom Props to ASP Custom Props.
######################################	     						
	     						my @segCustomProps = @{$segInst->{customProperties}{property}};
	     									foreach my $segCustOutP (@segCustomProps) 
	     									{
	     										if ( !($segCustOutP->{name} eq "WAS_EndpointInitialState") )
	     										{
	     											$custOutP="$custOutP {$segCustOutP->{name} $segCustOutP}";
	     										}
	     									}
	     						$custOutP="$custOutP}}" ;
	     						
                    print JSSJACL "puts \"********************************\"\n" ;
		     						print JSSJACL "puts \"Action   : Adding \"\n";
		     						print JSSJACL "puts \"Type     : Activation Specification \"\n";
		     						print JSSJACL "puts \"Property : $active->{name}_$segInst->{ID} \"\n";
		     						print JSSJACL "puts \"Node     : $node->{Name} \"\n";
		     						print JSSJACL "puts \"Jvm Name : $server->{Name} \"\n";
		     						print JSSJACL "puts \"SSL      : $sslType \"\n";
		     						print JSSJACL "puts \"MODE     : SEGMENT \"\n";
		     						if ( $scopeID == "1" )
		     						{
		     						print JSSJACL "puts \"Scope    : Cell \"\n";
		     							print JSSJACL "set out [createupdateActiveSpec $active->{name}_$segInst->{ID} [ getCellID \$cell ] { -name $active->{name}_$segInst->{ID} -jndiName $active->{jndiName}_$segInst->{ID} -destinationJndiName $active->{destinationJndiName} -destinationType javax.jms.Queue -qmgrName $active->{qmgrName} -qmgrHostname $active->{qmgrHostname} -qmgrPortNumber $active->{qmgrPortNumber} -qmgrSvrconnChannel $active->{qmgrSvrconnChannel} -messageSelector \"$segInst->{MessageSelector}\" -sslType $sslType $sslConf -wmqTransportType CLIENT $advanPropOut  } $custOutP ]\n";
		     						}
		     						elsif ($scopeID == "3")
		     						{
		     						print JSSJACL "puts \"Scope    : Jvm \"\n";
		     							print JSSJACL "set out [createupdateActiveSpec $active->{name}_$segInst->{ID} [getSrvrID \$cell $node->{Name} $server->{Name} ] { -name $active->{name}_$segInst->{ID} -jndiName $active->{jndiName}_$segInst->{ID} -destinationJndiName $active->{destinationJndiName} -destinationType javax.jms.Queue -qmgrName $active->{qmgrName} -qmgrHostname $active->{qmgrHostname} -qmgrPortNumber $active->{qmgrPortNumber} -qmgrSvrconnChannel $active->{qmgrSvrconnChannel} -messageSelector \"$segInst->{MessageSelector}\" -sslType $sslType $sslConf  -wmqTransportType CLIENT $advanPropOut  } $custOutP ]\n";
		     						}
		     						elsif ($scopeID == "2")
		     						{
		     						print JSSJACL "puts \"Scope    : Node \"\n";
		     							print JSSJACL "set out [createupdateActiveSpec $active->{name}_$segInst->{ID} [getNodeID \$cell $node->{Name} ] { -name $active->{name}_$segInst->{ID} -jndiName $active->{jndiName}_$segInst->{ID} -destinationJndiName $active->{destinationJndiName} -destinationType javax.jms.Queue -qmgrName $active->{qmgrName} -qmgrHostname $active->{qmgrHostname} -qmgrPortNumber $active->{qmgrPortNumber} -qmgrSvrconnChannel $active->{qmgrSvrconnChannel} -messageSelector \"$segInst->{MessageSelector}\" -sslType $sslType $sslConf  -wmqTransportType CLIENT $advanPropOut  } $custOutP ]\n";
		     						}
		     					    print JSSJACL "puts \"********************************\"\n" ;
	
}
sub writeCreateActivationSpecJACL {
	 my $active = $_[0] ;
 	 my $cluster = $_[1] ;
	 my $server = $_[2] ;
	 my $node = $_[3] ;
	 my $sslConfig = $_[4] ;
   my $scopeID =$_[5] ;
     
######################################
# Code to Read Segments Data
######################################
my @segmentInstancList=@{$JSXDxml->{ASP}->{Segments}->{Instance}};
my $asize = scalar @segmentInstancList;
#print "\n>>>>>>>>>>>>>>>>>$asize>>>>>>>>>>>>\n";
foreach my $segInst (@segmentInstancList)
{
	#print "\n>>>>>>>>>>>>>>>>>$segInst->{ID}>>>>>>>>>>>>\n";
	if ( !(trim($segInst->{ID}) eq "") )
	{
		writeCreateActivationSpecJACL_seg($active,$cluster,$server,$node,$sslConfig,$scopeID,$segInst);
	}
	else
	{
		writeCreateActivationSpecJACL_Nonseg($active,$cluster,$server,$node,$sslConfig,$scopeID);
	}
}
}
sub writeDeleteActivationSpecJACL_seg {
	my $active = $_[0] ;
	 my $cluster = $_[1] ;
	 my $server = $_[2] ;
	 my $node = $_[3] ;
	 my $scopeID = $_[4];
	 my $segInst =$_[5] ;
	                  print JSSJACL "puts \"********************************\"\n" ;
		     						print JSSJACL "puts \"Action   : Deleting \"\n";
		     						print JSSJACL "puts \"Type     : Activation Specification \"\n";
		     						print JSSJACL "puts \"Property : $active->{name}_$segInst->{ID} \"\n";
		     						print JSSJACL "puts \"Node     : $node->{Name} \"\n";
		     						print JSSJACL "puts \"Jvm Name : $server->{Name} \"\n";
		     						#print JSSJACL "set out [deleteActiveSpec [getSrvrID \$cell $node->{Name} $server->{Name} ] $active->{name}]\n";
		     						if ( $scopeID == "1" )
		     						{
		     						print JSSJACL "puts \"Scope    : Cluster \"\n";
		     						  print JSSJACL "set out [deleteActiveSpec [ getClusID \$cluster ] $active->{name}_$segInst->{ID}]\n";
		     						}
		     						elsif ($scopeID == "3")
		     						{
		     						print JSSJACL "puts \"Scope    : Jvm \"\n";
		     						  print JSSJACL "set out [deleteActiveSpec [getSrvrID \$cell $node->{Name} $server->{Name} ] $active->{name}_$segInst->{ID}]\n";
		     						}
		     						elsif ($scopeID == "2")
		     						{
		     						print JSSJACL "puts \"Scope    : Node \"\n";
		     						  print JSSJACL "set out [deleteActiveSpec [getNodeID \$cell $node->{Name} ] $active->{name}_$segInst->{ID}]\n";
		     						}
		     					    print JSSJACL "puts \"********************************\"\n" ;
		     					    print JSSJACL "puts \"********************************\"\n" ;
}
sub writeDeleteActivationSpecJACL_Nonseg {
	my $active = $_[0] ;
	 my $cluster = $_[1] ;
	 my $server = $_[2] ;
	 my $node = $_[3] ;
	 my $scopeID = $_[4];
	                  print JSSJACL "puts \"********************************\"\n" ;
		     						print JSSJACL "puts \"Action   : Deleting \"\n";
		     						print JSSJACL "puts \"Type     : Activation Specification \"\n";
		     						print JSSJACL "puts \"Property : $active->{name} \"\n";
		     						print JSSJACL "puts \"Node     : $node->{Name} \"\n";
		     						print JSSJACL "puts \"Jvm Name : $server->{Name} \"\n";
		     						#print JSSJACL "set out [deleteActiveSpec [getSrvrID \$cell $node->{Name} $server->{Name} ] $active->{name}]\n";
		     						if ( $scopeID == "1" )
		     						{
		     						print JSSJACL "puts \"Scope    : Cluster \"\n";
								  print JSSJACL "set ClusName $cluster\n";
		     						  print JSSJACL "set out [deleteActiveSpec [ getClusID \$ClusName ] $active->{name}]\n";
		     						}
		     						elsif ($scopeID == "3")
		     						{
		     						print JSSJACL "puts \"Scope    : Jvm \"\n";
		     						  print JSSJACL "set out [deleteActiveSpec [getSrvrID \$cell $node->{Name} $server->{Name} ] $active->{name}]\n";
		     						}
		     						elsif ($scopeID == "2")
		     						{
		     						print JSSJACL "puts \"Scope    : Node \"\n";
		     						  print JSSJACL "set out [deleteActiveSpec [getNodeID \$cell $node->{Name} ] $active->{name}]\n";
		     						}
		     					    print JSSJACL "puts \"********************************\"\n" ;
		     					    print JSSJACL "puts \"********************************\"\n" ;
}
sub writeDeleteActivationSpecJACL {
	my $active = $_[0] ;
	 my $cluster = $_[1] ;
	 my $server = $_[2] ;
	 my $node = $_[3] ;
	 my $scopeID = $_[4];
   
  #print "\n>>>>>>>>>>>ScopeID : $scopeID\n"    ;
######################################
# Code to Read Segments Data
######################################
my @segmentInstancList=@{$JSXDxml->{ASP}->{Segments}->{Instance}};
my $asize = scalar @segmentInstancList;
#print "\n>>>>>>>>>>>>>>>>>$asize>>>>>>>>>>>>\n";
foreach my $segInst (@segmentInstancList)
{
	#print "\nDelete : >>>>>>>>>>>>>>>>>$segInst->{ID} >>>$scopeID >>>>>>>>>>>>\n";
	if ( !(trim($segInst->{ID}) eq "") )
	{
		writeDeleteActivationSpecJACL_seg($active,$cluster,$server,$node,$scopeID,$segInst);
	}
	else
	{
		writeDeleteActivationSpecJACL_Nonseg($active,$cluster,$server,$node,$scopeID);
	}
} 
}
sub deleteActivationSpec {
################################################################################
#
# subroutine : deleteActivationSpec
# date       : 10 Aug 2011
# author     : Dharma Raju Maganti
# description: Subroutines to generate small sections of JACL
#
################################################################################
 #
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
    
 
}
sub createJMSDefJACL {
################################################################################
#
# subroutine : createJMSDefJACL
# date       : 17 February 2008
# author     : Dan Fitzpatrick
# description: Create the JACL to build the JMS config in WebSphere
#              All resources will be created with scope set to the server(s)
#              specified in the infra jsx file.  Almost all of the print
#              statements have been moved off to the various writeJACL*
#              subroutines in order to make this subroutine more readable.
#
# Available JACL procs:
#	proc getCellID {CellName} {
#       proc getClusID {ClusName} {
#	proc getNodeID {CellName NodeName} {
#	proc getSrvrID {CellName NodeName SrvrName} {
#	proc getProvID {CellName NodeName SrvrName PrvName} {
#	proc getDstList {Parent} {
#	proc getCfList {Parent} {
#   proc mkDst {DstName JndiName eJndiName DstDesc Parent} {
#   proc mkCf {CfName JndiName eJndiName CfDesc Parent} {
#   proc mkProv {PrvName PrvURL PrvContext PrvClasspath Parent} {
#
# COMMENT    : The nested foreach loops may seem redundant, and it would be
#              very easy to do away with them in this perl code.  However,
#              doing so would require that we shift loop processing into the
#              generated JACL code.  Because of the slowness of wsadmin, we
#              are keeping the loop processing here.
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
	my ($node, $srvr, $JMSProvider);
	my @QCFCOptionList = qw(agedTO connTO maxConn minConn pPol reapTime unuTO mapConfAlias);
	#
    # decide the jacl filename
    #
    if ($DELETE) {
        $jaclFile="${cfgDir}/${envPfxI}__JMSKill.jacl";
    } else {
        $jaclFile="${cfgDir}/${envPfxI}__JMSSetup.jacl";
    }
	ICSLogger(info,0,"Generating ${jaclFile}"); 
	if ( ! open(JSSJACL, "> ${jaclFile}")) {
		ICSLogger(error,0,"Could not open JACL output file!");
		die;
	}

	writeJACLHead();
	writeJACLCell();
	writeJACLClus();
    writeJACLPool() if (! $DELETE);
    writeJACLJ2C();
    writeJACLAuth() if (! $DELETE);
    my @NodeList = @{$JSXIxml->{JSX}->{NODE}};
	my @ProvList = @{$JSXDxml->{JSX}->{PROV}};
	# svrCnt is a Quick and Dirty way to make stuff happen only on the first server (like Q Validation)
	my $svrCnt=0;
    foreach $node (@NodeList) {
	    #print length($node)." : \"$node\"\n"; exit;
        writeJACLNode($node);
        my @SrvrList = @{$node->{SRVR}};
        foreach $srvr (@SrvrList) {
    	    writeJACLSrvr($srvr);
            foreach $JMSProvider (@ProvList) {
                writeJACLProv($JMSProvider);
                if (! $DELETE) {
                    writeJACLQCF($JMSProvider);
                    writeJACLDST($JMSProvider,$svrCnt);
                }
            }
            $svrCnt++;
        }
    }
    if ( (!$NOASP) )
    {
    	if ($DELETE)
    	{
    		processClusActiveSpec ;
    	}
    	else
    	{
    		processClusActiveSpec
    	}
    }
    print JSSJACL "\$AdminConfig save\n";
    # print JSSJACL "if {\$dmgr != {}} {\$AdminControl invoke \$dmgr syncActiveNodes Y}\n";
    print JSSJACL "syncAll\n";
    print JSSJACL "exit\n";
    close(JSSJACL);
    ICSLogger(info,0,"Finished generating ${jaclFile}");
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}		



sub writeJACLHead {
################################################################################	
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
   my $BQCP = "/appl/OMS/scripts:/appl/OMS/Software/lib/SonicMQ/sonic_ASPI.jar:/appl/OMS/Software/lib/SonicMQ/sonic_Channel.jar:/appl/OMS/Software/lib/SonicMQ/sonic_Client.jar:/appl/OMS/Software/lib/SonicMQ/sonic_Crypto.jar:/appl/OMS/Software/lib/SonicMQ/sonic_Selector.jar:/appl/OMS/Software/lib/SonicMQ/sonic_SF.jar:/appl/OMS/Software/lib/SonicMQ/sonic_SSL.jar:/appl/OMS/Software/lib/SonicMQ/sonic_XA.jar:/appl/OMS/Software/lib/SonicMQ/sonic_XMessage.jar";
    my $javaCmd = "/usr/local/opt/was/was70/java/jre/bin/java";
    my $BQJavaOpts = "-Xmx512M";
    print JSSJACL "#\n";
	print JSSJACL "# JACL generated by JMSSetup.pl\n";
	print JSSJACL "# DO NOT USE as stand-alone jacl!\n";
	print JSSJACL "#\n";
	#print JSSJACL "# Author: Rev. Dan Fitzpatrick, Sr.\n";
	print JSSJACL "#\n";
	print JSSJACL "source ${dir}/JMSProcs.jacl\n";
	print JSSJACL "set BQCP {$BQCP}\n";
	print JSSJACL "set javaCmd {$javaCmd}\n";
	print JSSJACL "set BQJavaOpts {$BQJavaOpts}\n";
	ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
	}


sub writeJACLPool () {
################################################################################
#
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################	
	#
	# Pool info
    # <POOL agedTO=0 connTO=180 maxConn=10 minConn=1 pPol="FailingConnectionOnly" reapTime=180 unuTO=1800 mapConfAlias="DefaultPrincipalMapping">
    my $JMSPool  = $JSXIxml->{JSX}->{POOL};
	my $QCFCOption;
	my @QCFCOptionList = qw(agedTO connTO maxConn minConn pPol reapTime unuTO mapConfAlias);
    foreach $QCFCOption (@QCFCOptionList) {
	    if ($JMSPool->{$QCFCOption} ne "") {
		    print JSSJACL "set $QCFCOption $JMSPool->{$QCFCOption}\n";
	    }
    }
    #
    # End of POOL tag processing
    #
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


	
sub writeJACLJ2C () {
################################################################################
#
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################
	#
	# J2C info
	# <J2C Name="OMS_MechID" userId="m26217">
    my @J2CList  = @{$JSXIxml->{JSX}->{J2C}};
    my $J2C;
    foreach $J2C (@J2CList) {
	    if (${J2C}->{Name} ne "") {
		    print JSSJACL "#\n";
            if (! $DELETE) {
                print JSSJACL "# Creating J2C Auth entry ${J2C}->{Name} for $J2C->{Provider}\n";
                print JSSJACL "#\n";
                # mkAuthData {Alias User}
                print JSSJACL "mkAuthData $J2C->{Provider} $J2C->{Name} $J2C->{userId}\n";
            } else {
                print JSSJACL "# Killing J2C Auth entry ${J2C}->{Name} for $J2C->{Provider}\n";
                print JSSJACL "#\n";
                print JSSJACL "killAuthData $J2C->{Provider} $J2C->{Name}\n";
            }
        } else {
            ICSLogger(info,0,"Ignoring J2C entry with no name.");
        }
    }
    #
    # End of J2C tag processing
    #
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


sub writeJACLAuth () {
################################################################################
#
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################	
	#
	# AUTH
	# <AUTH Name="OMS_MechID">
    my $AuthAlias = $JSXIxml->{JSX}->{AUTH}{Name};
	if ($AuthAlias ne "") {
		print JSSJACL "#\n";
		print JSSJACL "# Setting default J2C Auth Alias\n";
		print JSSJACL "#\n";
		print JSSJACL "set authAlias $AuthAlias\n";
		#### TIBCO ####
		$AuthAlias_E = $AuthAlias;
		###############
	} else {
		print JSSJACL "#\n";
		print JSSJACL "# Using default J2C Auth Alias from JMSProcs.jacl\n";
		print JSSJACL "#\n";
	}
    print JSSJACL "set myAuthEntry [ckAuthData \$authAlias]\n";
    print JSSJACL "if { \$myAuthEntry == {} } {\n";
    print JSSJACL "    puts \"##################################################################\"\n";
    print JSSJACL "    puts \"ERROR: There is no J2C Authentication Data for \${authAlias}!\"\n";
    print JSSJACL "    exit 1\n";
    print JSSJACL "    }\n";
	#### TIBCO ####
  my $AuthAlias = $JSXIxml->{JSX}->{AUTH_T}{Name};
	if ($AuthAlias ne "") {
		print JSSJACL "#\n";
		print JSSJACL "# Setting default J2C Auth Alias\n";
		print JSSJACL "#\n";
		print JSSJACL "set authAlias $AuthAlias\n";
		$AuthAlias_T = $AuthAlias;
	} else {
		print JSSJACL "#\n";
		print JSSJACL "# Using default J2C Auth Alias from JMSProcs.jacl\n";
		print JSSJACL "#\n";
	}
  print JSSJACL "set myAuthEntry [ckAuthData \$authAlias]\n";
  print JSSJACL "if { \$myAuthEntry == {} } {\n";
  print JSSJACL "    puts \"##################################################################\"\n";
  print JSSJACL "    puts \"ERROR: There is no J2C Authentication Data for \${authAlias}!\"\n";
  print JSSJACL "    exit 1\n";
  print JSSJACL "    }\n";
	###############    
    #
    # End of Auth tag processing
    #
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

	
sub writeJACLCell () {
################################################################################
#
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################
    my $cellName = $JSXIxml->{JSX}->{CELL}{Name};
    print JSSJACL "#\n";
    print JSSJACL "# Set up Cell info\n";
    print JSSJACL "#\n";
	print JSSJACL "set CellName $cellName\n";
	print JSSJACL "set dmgr [\$AdminControl completeObjectName type=DeploymentManager,*]\n";
	print JSSJACL "set CellID [getCellID \$CellName]\n";
	ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

sub writeJACLClus () {
################################################################################
#
# subroutine : writeJACL*
# date       : 01 August 2012
# author     : Narendar Murarishetty
# description: Subroutines to generate small sections of JACL
################################################################################
    my $clusName = $JSXIxml->{JSX}->{CLUS}{Name};
    print JSSJACL "#\n";
    print JSSJACL "# Set up Clus info\n";
    print JSSJACL "#\n";
        print JSSJACL "set ClusName $clusName\n";
        print JSSJACL "set ClusID [getClusID \$ClusName]\n";
        ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

	
sub writeJACLNode () {
################################################################################
#
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################
    my $node = shift(@_);
    my $rck1 = ref($node);
    ($rck1) || die "DANGER!  arg 1 to writeJACLNode is not a ref!\n";
    # print "Node: $node->{Name}\n";
    print JSSJACL "    #\n";
    print JSSJACL "    # Set up node info\n";
    print JSSJACL "    #\n";
    if (length($node->{Name})>1) {
    	print JSSJACL "    set NodeName $node->{Name}\n";
    	print JSSJACL "    set NodeID [getNodeID \$CellName \$NodeName]\n";
	}
	else
	{
		#There is no defined Node breakout, we're doing a Cell level setting, so dummy these values.
		print JSSJACL "    set NodeName \"\"\n";
		print JSSJACL "    set NodeID \"\"\n";	
	}
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

	
sub writeJACLSrvr () {
################################################################################
#
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################
    my $srvr = shift(@_);
    my $rck1 = ref($srvr);
    ($rck1) || die "DANGER!  arg 1 to writeJACLSrvr is not a ref!\n";
    # print "  Server: $srvr->{Name}\n";
    print JSSJACL "        #\n";
    print JSSJACL "        # Set up server info\n";
    print JSSJACL "        #\n";
    if (length $srvr->{Name}>1) {
    	print JSSJACL "        set SrvrName $srvr->{Name}\n";
    	print JSSJACL "        set SrvrID [getSrvrID \$CellName \$NodeName \$SrvrName]\n";
	}
	else
	{
		#There is no defined SRVR values - we're either doing a Cell or Node level setting - dummy these values.
		print JSSJACL "        set SrvrName \"\"\n";
    	print JSSJACL "        set SrvrID \"\"\n";
	}
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


	
sub writeJACLProv () {
################################################################################
#
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################
    my $JMSProvider = shift(@_);
    my $rck1 = ref($JMSProvider);
    ($rck1) || die "DANGER!  arg 1 to writeJACLProv is not a ref!\n";
    my $prvCP;
    my $prvCtx;
    #### TIBCO ####
    my $prvCusProp;
    ###############
    # print "    JMS Provider: $JMSProvider->{Name}\n";
    print JSSJACL "            #\n";
    if (! $DELETE) {
        print JSSJACL "            # Create a JMS Provider\n";
        print JSSJACL "            #\n";
        print JSSJACL "            set PrvName $JMSProvider->{Name}\n";
        print JSSJACL "            set PrvID [getProvID \$CellName \$ClusName \$NodeName \$SrvrName \$PrvName]\n";
        print JSSJACL "            if { [string length \$PrvID] > 0 } { puts \"INFO: Provider \$PrvName does not exist yet.\" }\n";
        if ( $JMSProvider->{Classpath} eq "" ) {
	        # use default if not specified
	        #### TIBCO ####
	        #$prvCP=$defPrvClasspath;
	  				if ( $JMSProvider->{Name} eq "SS_TIBCOProvider" ) {
	  					$prvCP=$defTibcoPrvClasspath;
	  				}
	  				elsif ( $JMSProvider->{Name} eq "SS_FUSIONBUSProvider" ) {
	  					$prvCP=$defFUSIONPrvClasspath;
	  				}
                                        elsif ( $JMSProvider->{Name} =~ m/^SS_SOLACEProvider/ ) {
                                                $prvCP=$defSolacePrvClasspath;
                                        }
	  				else {
	  					$prvCP=$defEMBUSPrvClasspath;
	  				}
	  			###############	  				    		  
        } else {
	        $prvCP=$JMSProvider->{Classpath};
        }
        
        if ($JMSProvider->{Context} eq "" ) {
            #### TIBCO ####
            #$prvCtx=$defPrvContext;
            if ( $JMSProvider->{Name} eq "SS_TIBCOProvider" ) {
	  					$prvCtx=$defTibcoPrvContext;
	  				}
	  				elsif ( $JMSProvider->{Name} =~ m/^SS_FUSIONBUSProvider.*/ ) {
	  					$prvCtx=$defFUSIONPrvContext;
	  				}
                                        elsif ( $JMSProvider->{Name} =~ m/^SS_SOLACEProvider/ ) {
                                                $prvCtx=$defSolacePrvContext;
                                        }
	  				else {
	  					$prvCtx=$defEMBUSPrvContext;
	  				}
        		###############
        } else {
            $prvCtx=$JMSProvider->{Context};
        }
        #### TIBCO ####
        if ( $JMSProvider->{Name} eq "SS_TIBCOProvider" ) {
        	$prvCusProp=$defTibcoPrvCustProp;
        }
        elsif ( $JMSProvider->{Name}=~ m/^SS_SOLACEProvider/ ) {
                getSolaceCustomProperty($JMSProvider);
                $prvCusProp=$defSolacePrvCustProp;
        }
	else {
					$prvCusProp=$defPrvCustProp;
				}
				###############
        print JSSJACL "            set PrvClasspath \"$prvCP\"\n";
        print JSSJACL "            set PrvURL \"$JMSProvider->{URL}\"\n";
        print JSSJACL "            set PrvContext \"$prvCtx\"\n";
        #Added for TIBCO. New argument for mkProv function. - yh6535
        print JSSJACL "						 set PrvCustomProp \"$prvCusProp\"\n";
        #Altered to allow for Cell / Node / Srvr level differences - mg3593
        print JSSJACL "            if { [string length \$CellID] > 0 } { set BaseID \$CellID }\n";
        print JSSJACL "            if { [string length \$ClusID] > 0 } { set BaseID \$ClusID }\n";
	print JSSJACL "            if { [string length \$NodeID] > 0 } { set BaseID \$NodeID }\n";
        print JSSJACL "            if { [string length \$SrvrID] > 0 } { set BaseID \$SrvrID }\n";
        print JSSJACL "            set PrvID [mkProv \$PrvName \$PrvURL \$PrvContext \$PrvClasspath \$PrvCustomProp \$BaseID]\n";
    } else {
        print JSSJACL "            # Delete a JMS Provider\n";
        print JSSJACL "            #\n";
        print JSSJACL "            set PrvName $JMSProvider->{Name}\n";
        #print JSSJACL "            set PrvID [getProvID \$CellName \$NodeName \$SrvrName \$PrvName]\n";
        #Altered to allow for Cell / Node / Srvr level differences - mg3593
        print JSSJACL "            if { [string length \$CellID] > 0 } { set BaseID \$CellID }\n";
        print JSSJACL "            if { [string length \$ClusID] > 0 } { set BaseID \$ClusID }\n";
	print JSSJACL "            if { [string length \$NodeID] > 0 } { set BaseID \$NodeID }\n";
        print JSSJACL "            if { [string length \$SrvrID] > 0 } { set BaseID \$SrvrID }\n";
        print JSSJACL "            set result [killProv \$PrvName \$BaseID]\n";
    }
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

	
sub writeJACLQCF () {
################################################################################
#
# subroutine : writeJACL*
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################
    my $JMSProvider = shift(@_);
    my $rck1 = ref($JMSProvider);
    ($rck1) || die "DANGER!  arg 1 to writeJACLQCF is not a ref!\n";
    my @QCFCList = @{$JMSProvider->{QCFC}};
	my @QCFCOptionList = qw(agedTO connTO maxConn minConn pPol reapTime unuTO mapConfAlias);
	my ($QCFCOption, $QConnFact);
	foreach $QConnFact (@QCFCList) {
	    # <QCFC Name="QCFName" JNDI="QCF_Internal_JNDI_Name" EJNDI="QCF_External_JNDI_Name" Desc="QCF Desc">
	    print JSSJACL "                #\n";
	    print JSSJACL "                # Create a Q Connection Factory\n";
	    print JSSJACL "                #\n";
	    print JSSJACL "                set CfName $QConnFact->{Name}\n";
	    print JSSJACL "                set JndiName $QConnFact->{JNDI}\n";
	    print JSSJACL "                set eJndiName $QConnFact->{EJNDI}\n";
	    print JSSJACL "                set CfDesc {$QConnFact->{Desc}}\n";
	    # Parent = last provider ID
	    foreach $QCFCOption (@QCFCOptionList) {
	        if ($QConnFact->{$QCFCOption} ne "") {
		        print JSSJACL "                set $QCFCOption $QConnFact->{$QCFCOption}\n";
		    }
        }
	    #### TIBCO ####
	    if ( $JMSProvider->{Name} eq "SS_TIBCOProvider" ) {
	    	print JSSJACL "set authAlias $AuthAlias_T\n";
	    	}	else {
	    		print JSSJACL "set authAlias $AuthAlias_E\n";
	    }
	    ###############
	    if ($QConnFact->{authAlias} ne "") {
            # Use local authAlias property if available.
            print JSSJACL "                set myAuthAlias $QConnFact->{authAlias}\n";
        } else {
    	    # No local authAlias, so use default which is set in JMSProcs.jacl OR at the top of this dynamic jacl.
            print JSSJACL "                set myAuthAlias \$authAlias\n";
	    }
	    # mkPool {agedTO connTO maxConn minConn pPol reapTime unuTO}
	    print JSSJACL "                set CfCPool [mkPool \$agedTO \$connTO \$maxConn \$minConn \$pPol \$reapTime \$unuTO \"connectionPool\"]\n";
	    print JSSJACL "                set CfSPool [mkPool \$agedTO \$connTO \$maxConn \$minConn \$pPol \$reapTime \$unuTO \"sessionPool\"]\n";
	    # mkCf {CfName JndiName eJndiName CfDesc AuthAlias CfCPool CfSPool MapConfAlias Parent}
	    #print JSSJACL "                lappend QcfIDLst [mkCf \$CfName \$JndiName \$eJndiName \$CfDesc \$myAuthAlias \$CfCPool \$CfSPool \$mapConfAlias \$PrvID]\n";
	    ##### FUSION #####
	    # For Fusion QCF creation, call different method without J2C alias details
	    if ( $JMSProvider->{Name} eq "SS_FUSIONBUSProvider" ) {
	    	print JSSJACL "lappend QcfIDLst [mkFusionCf \$CfName \$JndiName \$eJndiName \$CfDesc \$CfCPool \$CfSPool \$mapConfAlias \$PrvID]\n";
	    }
            elsif ($JMSProvider->{Name} =~ m/^SS_SOLACEProvider/) {
                print JSSJACL "lappend QcfIDLst [mkFusionCf \$CfName \$JndiName \$eJndiName \$CfDesc \$CfCPool \$CfSPool \$mapConfAlias \$PrvID]\n";
            }	
		else {
	    		print JSSJACL "lappend QcfIDLst [mkCf \$CfName \$JndiName \$eJndiName \$CfDesc \$myAuthAlias \$CfCPool \$CfSPool \$mapConfAlias \$PrvID]\n";
	    		}
	    ##################
	    }
	    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
    }   
 
	
sub writeJACLDST () {
################################################################################
# subroutine : writeJACLDST
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
################################################################################
    my $JMSProvider = shift(@_);
    my $validated = shift(@_);
    my $rck1 = ref($JMSProvider);
    ($rck1) || die "DANGER!  arg 1 to writeJACLDST is not a ref!\n";
    my @QDestList = @{$JMSProvider->{DEST}};
    my $QDest;
    foreach $QDest (@QDestList) {
	    print JSSJACL "                #\n";
		print JSSJACL "                # Create a Q Destination\n";
		print JSSJACL "                #\n";
		print JSSJACL "                set DstName $QDest->{Name}\n";		    
		print JSSJACL "                set DstJndi $QDest->{JNDI}\n";
		print JSSJACL "                set DstEJndi $QDest->{EJNDI}\n";
		print JSSJACL "                set DstDesc {$QDest->{Desc}}\n";
		if (! $validated) {
    		writeJACLQVal($JMSProvider,$QDest);
		}
###########################################
# Destination bypassing if no Destination given
#############################################
if ( !( $QDest->{Name} eq "") )
		{
        print JSSJACL "                lappend QDstIDLst [mkDst \$DstName \$DstJndi \$DstEJndi \$DstDesc \$PrvID]\n";
    } 
        ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

	
sub writeJACLQVal () {
################################################################################
# subroutine : writeJACLQVal
# date       : 26 February 2008
# author     : Dan Fitzpatrick
# description: Subroutines to generate small sections of JACL
# Changes    : 03/28/08 - df7535 - Added support for VQCF Element.
################################################################################
    my $JMSProvider = shift(@_);
    my $QDest = shift(@_);
    my $rck1 = ref($JMSProvider);
    my $rck2 = ref($QDest);
    (!$rck1 || !$rck2) && die "DANGER!  args to writeJACLQVal are not refs!\n";
    my @VQCFLst = @{$QDest->{VQCF}};
    my $VQCF;
    my $DstCfLst;
    #
    # Added 3/14/2008 to validate Queues
    #
    # 3/28 - push the CF attr from DEST element into the VQCF array.
    # This is done for backward compatibility though it should not be needed.
    #
    if (my $DstCF = $JMSProvider->{QCFC}('JNDI','eq',$QDest->{CF})) {
        my $newVQCF = {
            Name => $DstCF->{Name}
        };
        push(@VQCFLst, $newVQCF);
    }
    #
    #### TIBCO ####
    #print JSSJACL "                if {! [info exists myUser2] } {set myUser2 [getAuthData \$myAuthAlias]}\n";
    print JSSJACL "                 set myUser2 [getAuthData \$myAuthAlias]\n";
    ###############
    foreach $VQCF (@VQCFLst) {
        # If no VQCF elements are present, we'll still get one empty return...
        next if ($VQCF->{Name} eq "");
        my $DstCF = $JMSProvider->{QCFC}('Name','eq',$VQCF->{Name});
        $DstCfLst .= " " . "\"$DstCF->{Name}\"";
    }
        if ( $JMSProvider->{Name} =~ m/^(TIBCO|EMBUS).*/ ) {
        print JSSJACL "                set DstCfLst {$DstCfLst}\n";
        print JSSJACL "                foreach DstCF \$DstCfLst {\n";
        # Added protection against null CFs in the list...
        print JSSJACL "                    if {\$DstCF==\"\"} {continue}\n";
        # Since we've already created the qCF, let's use the auth alias that we established for it.
        #print JSSJACL "                    set cfID [\$AdminConfig getid /Cell:\$CellName/Node:\$NodeName/Server:\$SrvrName/JMSProvider:$JMSProvider->{Name}/GenericJMSConnectionFactory:\$DstCF/]\n";
        #Need to build the criterion based on what level we're operating at.
        print JSSJACL "                    set cFScope \"\"\n";
        print JSSJACL "                    if {[string length \$CellName] > 0} {append cFScope \"/Cell:\" \$CellName}\n";
		print JSSJACL "                    if {[string length \$NodeName] > 0} {append cFScope \"/Node:\" \$NodeName}\n";
		print JSSJACL "                    if {[string length \$SrvrName] > 0} {append cFScope \"/Server:\" \$SrvrName}\n";
		print JSSJACL "                    if {[string length \$PrvName] > 0} {append cFScope \"/JMSProvider:\" \$PrvName \"/\"}\n";
        print JSSJACL "                    append cFScope \"GenericJMSConnectionFactory:\$DstCF/\"\n"; 
        print JSSJACL "                    set cfID [\$AdminConfig getid \$cFScope]\n";
        print JSSJACL "                    set cfEJNDI [\$AdminConfig showAttribute \$cfID externalJNDIName]\n";
        print JSSJACL "                    set myAuthAlias [\$AdminConfig showAttribute \$cfID authDataAlias]\n";

        print JSSJACL "                    set myUser1 [getAuthData \$myAuthAlias]\n";
    # If the last auth entry we created is the same user we're trying to use now, we won't prompt for the password.
    # We might get a couple false failures this way, but better than prompting for the same password over and over.
    # [string compare $s1 $s2] returns a true value (non-zero) if the condition $s1==$s2 is false...
    # how stupid is that?!!?!!
    print JSSJACL "                    if [string compare \$myUser2 \$myUser1] {set Password {}}\n";
    print JSSJACL "                    while {![string compare \$Password \"\"]} {\n";
    print JSSJACL "                        puts \"===>     PROMPT: Please enter the password for queue user \${myUser2} (\${mgrNode}/\${myAuthAlias})\"\n";
    print JSSJACL "                        gets stdin Password\n";
    print JSSJACL "                        }\n";
    print JSSJACL "                    set myUser2 [getAuthData \$myAuthAlias]\n";
    print JSSJACL "                    puts \"         INFO: Validating Queue \$DstName with CF=\$DstCF\"\n";
    print JSSJACL "                    set rc [exec \$javaCmd \$BQJavaOpts -classpath \$BQCP BrowseQueue \$PrvURL \$myUser2 \$Password \"\$DstEJndi\" \"\$cfEJNDI\"]\n";
    print JSSJACL "                    if [string compare \${rc} \"False\"] {\n";
    print JSSJACL "                        puts \"===>     INFO: Connection to \$DstName succeeded with CF=\$DstCF.\"\n";
    print JSSJACL "                    } else {\n";
    print JSSJACL "                        puts \"xxx>     WARNING: Queue validation failed for \$DstName with CF=\$DstCF.\"\n";
    print JSSJACL "                    }\n";
    print JSSJACL "                }\n";
    # ^^^^^ 3/14/2008 - Added Q Validation
    # ^^^^^ 3/28/2008 - Added Q Validation against multiple QCFs
    		}
    }
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


sub execJACL {
################################################################################
# subroutine : execJACL
# date       : 25 February 2008
# author     : Dan Fitzpatrick
# description: Executes the JACL generated by this program.
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
  #my $wsResp = `wsadmin.sh -f ${cfgDir}/${envPfxI}_JMSSetup.jacl"`;
  #print "\n\nwsadmin.sh completed.  Response received:\n$wsResp\n\n";
  ICSLogger(info,0,"Executing ${jaclFile}");
  prtSep();
  my $result = system("wsadmin.sh -f ${jaclFile}");
  $wsadminResult=$result;
  prtSep();
  ICSLogger(info,0,"wsadmin return code: $result");
  ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

sub prtSep {
################################################################################
#
# subroutine : prtSep
# date       : 17 February 2008
# author     : Dan Fitzpatrick
# description: print a separator line
#
################################################################################
  ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
  my $i = 0;
  print "\n";
  while ($i++ <= 50) {
    print "#";
    }
  print "\n";
  ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
  }

sub checkJMSProcs {
#################################################################################
##
## subroutine : checkJMSProcs
## date       : 26 February 2008
## author     : Dan Fitzpatrick
## description: Make sure the JMSProcs.jacl file is in the same directory
##            : that ICSetup.pl is running from.
##
#################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    my $fileName = basename($0);
    $dir = dirname($0);
    if (!(-f "${dir}/JMSProcs.jacl")) {
        ICSLogger(error,0,"JMSProcs.jacl must exist in the same path as ${fileName}");
        die;
    }
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}
sub checkBQ {
#################################################################################
##
## subroutine : checkBQ
## date       : 12 June 2008
## author     : Dan Fitzpatrick
## description: Make sure BrowseQueue exists
##
#################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
   #my $BQCP = "/appl/OMS/scripts:/appl/OMS/Software/lib/SonicMQ/sonic_ASPI.jar:/appl/OMS/Software/lib/SonicMQ/sonic_Channel.jar:/appl/OMS/Software/lib/SonicMQ/sonic_Client.jar:/appl/OMS/Software/lib/SonicMQ/sonic_Crypto.jar:/appl/OMS/Software/lib/SonicMQ/sonic_Selector.jar:/appl/OMS/Software/lib/SonicMQ/sonic_SF.jar:/appl/OMS/Software/lib/SonicMQ/sonic_SSL.jar:/appl/OMS/Software/lib/SonicMQ/sonic_XA.jar:/appl/OMS/Software/lib/SonicMQ/sonic_XMessage.jar:/appl/OMS/scripts/BrowseQueue.class:/appl/OMS/scripts/BrowseQueue.java";
    my $BQCP = "/appl/OMS/scripts:/appl/OMS/scripts/BrowseQueue.class:/appl/OMS/scripts/BrowseQueue.java";
    my @BQCP=split /:/, $BQCP;
    my $BQel;
    foreach $BQel (@BQCP) {
    	if ( ! (-e $BQel) ) {
    		ICSLogger(error,1,"$BQel does not exist.  Dying.");
    		die;
    	}
    }
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

sub getSpring {
################################################################################
#
# subroutine : getSpring
# date       : 2 April 2008
# author     : Dan Fitzpatrick
# description: Check existence of and read XML from Spring Template file
# arguments  : 
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    my $springFile = shift(@_);
    if (! -f $springFile) {
        ICSLogger(error,0,"Spring file not found ($springFile)");
        die;
    }
    my $springData = XML::Smart->new($springFile);
    ICSLogger(debug,2,length($springData->data({nometagen => 1, noheader =>1})) . " bytes read from $springFile");
    return $springData;
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

sub setSpring {
################################################################################
#
# subroutine : setSpring
# date       : 2 April 2008
# author     : Dan Fitzpatrick
# description: Edits the Spring XML object in memory.
# arguments  : springData - XML::Smart object containing entire Spring XML file structure.
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    my $springFile=shift;
    my $springXML=XML::Twig->new(keep_atts_order=>1,keep_spaces=>1);    # create the twig
    $springXML->parsefile($springFile); # build it
    my $springRoot=$springXML->root;

    my $icdXML=XML::Twig->new(keep_atts_order=>1,keep_spaces=>1);    # create the twig
    $icdXML->parsefile( "$ICDFile"); # build it
    #$icdXML->parsefile( $ICDFile); # build it
    my $icdRoot=$icdXML->root;
    #($springXML) || die "ERROR!  springData lost entering setSpring.";

    my @ICDSpring=$icdRoot->children("SpringJMS");
    for my $item (@ICDSpring) {
        ICSLogger(info,0,"ICDObject   : $item->{att}->{name}");
        #Determine if JMS, jaxws or http object and process accordingly.
        my ($type)=($item->{att}->{addrPath} =~m/\/beans\/([jms:conduit|jaxws:client]+)\//);
        unless ($type) {
            warn "No Valid Type Found! Skipping $item->{att}->{name}.";
            next;
        }
        my $match=0;
        my @springTypeList= $springRoot->children($type);
        for my $s_item ( @springTypeList ){
            last if ($match);
            unless ("$item->{att}->{name}" eq "$s_item->{att}->{name}"){
                #ICSLogger(debug,1,"NO MATCH"); 
                next;
            }   
            ICSLogger(info,0,"MATCH to");
            $match++;
            #Handle the patched objects
            ICSLogger(info,0,"SpringObject: $s_item->{att}->{name}");
            my $active;
            my %new_atts;
            if ($type =~/jms/){
                #isolate the spring jms:address section hash
                $active=$s_item->first_child('jms:address');		
                #isolate the spring jms:JMSNamingProperty array from the jms:address element
                my @s_item_JNP=$active->children('jms:JMSNamingProperty');
                #isolate the icd jms:NamingProperty array
                my @item_JNP=$item->children('jms:JMSNamingProperty');
                my $cnt=@s_item_JNP;
                for my $c (0..($cnt-1)) {
                    ICSLogger (debug,1,"$s_item_JNP[$c]->{att}->{name}");
                    $s_item_JNP[$c]->set_atts($item_JNP[$c]->atts);
                    ICSLogger (debug,1,"Set to:");
                    ICSLogger (debug,1,"$item_JNP[$c]->{att}->{value}");
                }
                for my $s_i (keys %{$active->atts}){
                    #$new_atts{$s_i}=$active->atts->{$s_i};
                    #if ($item->atts->{$s_i}) {
                    #    $new_atts{$s_i}=$item->atts->{$s_i}
                    #}
                    if ($item->{att}->{$s_i}) {
                        $active->{att}->{$s_i}=$item->{att}->{$s_i};
                    }
                    ICSLogger (debug,1,"$s_i");
                    #ICSLogger (debug,1,"Set to:");
                    ICSLogger (debug,1,"$active->{att}->{$s_i}");
                }
            }
            else  
            {
                #It's a jaxws - handle it.
                #isolate the spring jaxws:client section hash
                $active=$s_item;
                for my $s_i (keys %{$active->atts}){
                    if (defined($item->{att}->{$s_i})) {
                        $active->{att}->{$s_i}=$item->{att}->{$s_i};
                    }
                    ICSLogger (debug,1,"$s_i");
                    #ICSLogger (debug,1,"Set to:");
                    ICSLogger (debug,1,"$active->{att}->{$s_i}");
                }
            }
        }
    ICSLogger(debug,1,"Success.");
    }
    #Write out the Spring file.
    $springXML->print_to_file("$springFile");
    ICSLogger(debug,0,"$springFile updated for $ICDFile values.");
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}

sub backupSpring{
################################################################################
#
# subroutine : backupSpring
# date       : 14 March 2010
# author     : Mike Gucciard (mg3593@att.com)
# description: Creates a backup of the Connector subdirectories under
#              Connector/backups.
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    my $envDir = $JSXIxml->{JSX}->{ENV}->{Path}->content;
    my $connDir = $envDir . "/Connector/artix";
    my @lt = localtime(time);
    my $timestamp = sprintf "%4d_%02d_%02d_%02d%02d%02d", $lt[
    +5]+1900, $lt[4]+1, @lt[3,2,1,0] ;
    #my $timestamp=sprintf "%4d%02d",$lt[5]+1900,$lt[4]+1;
    #make sure we have a Spring file where we expect it.
    if (-e "$connDir/OmsArtixSpringConfig.xml"){
        if (! -d "$connDir/backup") {
            mkdir "$connDir/backup";
        }
        copy("$connDir/OmsArtixSpringConfig.xml",
             "$connDir/backup/OmsArtixSpringConfig".$timestamp.".xml");
    }
    if (-e "$connDir/backup/OmsArtixSpringConfig".$timestamp.".xml") {
        ICSLogger(info,0,"OmsArtixSpringConfig.xml backup succeeded.");
    }
    else
    {
        ICSLogger(warn,0,"Backup of existing Spring file failed!");
    }
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}
sub doSpringFile {
################################################################################
#
# subroutine : doSpringFile
# date       : 29 Jan 2010
# author     : Mike Gucciard (mg3593@att.com)
# description: Load Spring template file, apply <Spring> values against template.
#              
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    backupSpring;
    my $mySpring;
    my $envDir = $JSXIxml->{JSX}->{ENV}->{Path};
    my $connDir = $envDir . "/Connector/artix";
    my $springFile= $connDir ."/OmsArtixSpringConfig.xml";

    ICSLogger(info,0,"Processing Spring file.");
        ICSLogger(info,0,"Reading $springFile");
        my $springData = getSpring($springFile);
        ($ENABLE_DEBUG) && ICSLogger(debug,2,": getSpring returned " . length($springData->data) . " bytes.");
        ($ENABLE_DEBUG) && ICSLogger(debug,2,": Spring File: $springFile");
        #ICSLogger(info,0,"Updating $springFile");
        my %TempHash;
        for my $entry (@{$springData->{beans}->{"jms:conduit"}}) {
                #print "Type JMS : $entry->{name}\n";
                $TempHash{"jms:conduit"}{$entry->{name}} ++;
                #
        }
        for my $entry (@{$springData->{beans}->{"jaxws:client"}}) {
                #print "Type HTTP : $entry->{name}\n";
                $TempHash{"jaxws:client"}{$entry->{name}} ++;
                #
        }
                for my $entry (@{$springData->{beans}->{"http:conduit"}}) {
                #print "Type HTTP : $entry->{name}\n";
                $TempHash{"http:cconduit"}{$entry->{name}} ++;
                #
        }
        for my $icd_entry (@{$JSXDxml->{SpringJMS}}) {
                 if ( $TempHash{"jms:conduit"}{$icd_entry->{name}} ) {
                        #print "Match $icd_entry->{name}\n";
                        next;
                 }
                 elsif ($TempHash{"jaxws:client"}{$icd_entry->{name}} ) {
                        #print "Match $icd_entry->{name}\n";
                        next;
                 }
                 #elsif ($TempHash{"http:conduit"}{$icd_entry->{name}} ) {
                        #print "Match $icd_entry->{name}\n";
                 #}
                 else
                {
                        print "NO MATCH for ICD $icd_entry->{name} !!\n";
                        $TempHash{MISMATCH}++;
                }
        }
        #Error and prompt if $TempHash{MISMATCH} exists;
        if ($TempHash{MISMATCH}) {
                print "FATAL ERROR:  $TempHash{MISMATCH} mismatches between ICD and Spring XML files.  Exiting!";
                exit(1);
        }
        setSpring($springFile);
        
        #($ENABLE_DEBUG) && ICSLogger(debug,2,": setSpring returned " . length($springData->data) . " bytes.");
        
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}
# sub dbConn {
# ################################################################################
# #
# # subroutine : dbConn
# # date       : 4 April 2008
# # author     : Dan Fitzpatrick
# # description: Establishes a connection to the DB.  We only want to do this
# #              once, so it makes sense to have it as a separate function.
# #
# ################################################################################
#     ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
#     # get JSX DB attribs
#     my $dbInfo   = $JSXIxml->{JSX}->{DB};
#     my $dbUser   = $dbInfo->{User};
#     my $dbInst   = $dbInfo->{Inst};
#     print "Please enter the password for $dbUser\@$dbInst:";
#     ReadMode(2);
#     my $dbPass = ReadLine(0);
#     chomp $dbPass;
#     # my $dbPass = "db50lsoms";
#     ReadMode(0);
#      
#     ICSLogger(debug,0,"\nlength(\$dbPass) = ". length($dbPass));
#     
#     if (! ($dbInst && $dbUser && $dbPass)) {
#         # Again not fatal, but can't check DB if full DB info is not provided
#         ICSLogger(warn,0,"DB Instance, User, and Password must be provided in order to check or update the DB.");
#         $NODB=1;
#         return;
#     }
#     
#     ICSLogger(debug,0,"Connecting to $dbUser/$dbPass\@$dbInst.");
#     if ( ! ( $dbh=DBI->connect("dbi:Oracle:$dbInst",$dbUser,$dbPass ) ) ) {
#         ICSLogger(error,0,"Unable to connect to $dbUser\@$dbInst: $DBI::errstr\n       Disabling DB updates.");
#         $NODB=1;
#         return;
#     }
#     ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
# }
# 
# 
# sub dbDis {
# ################################################################################
# #
# # subroutine : dbDis
# # date       : 14 April 2008
# # author     : Dan Fitzpatrick
# # description: Disconnects from the DB.  No frills.
# #
# ################################################################################
#     ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
#     # $dbh->disconnect();
#     ICSLogger(debug,0,"DB Handle disconnected.");
#     ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
# }


sub checkContract {
################################################################################
#
# subroutine : checkContract
# date       : 4 April 2008
# author     : Dan Fitzpatrick
# description: Checks TBCN_CONTRACT table against all CONTRACTS listed for a
#              given WSDL in the -ICD.xml file.
#
################################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    # icdWsdlTag = pointer to the WSDL element in the ICD file
    my $icdWsdlTag = shift(@_);
    my $rck1 = ref($icdWsdlTag);
    # get WSDL DB attribs;
    my ($file, $update, $contract, @updateSQL);
    my @contractList = @{$icdWsdlTag->{CONTRACT}};
    my $contractCnt = @contractList;
    ICSLogger(debug,2,"checking $contractCnt contracts...");
    foreach $contract (@contractList) {
        next if (! $contract);
        my $contractName = $contract->{Name};
        my $functionID = $contract->{Function};
        my $pIndex = $contract->{PIndex};
    
        ICSLogger(info,0,"Contract Name=$contractName\nfunctionID  =$functionID");
        # Both Contract and Function attributes must be provided in order to check the DB.
        if (! ($contractName && $functionID)) {
            # It's not a fatal issue though - just return and move on with the next contract
            ICSLogger(info,0,"Contract Name and FunctionID must both be supplied in order to check or update the DB.");
            next;
        }
    
        # get JSX env attribs
        ICSLogger(debug,2,"Checking ENV element.");
        if (! ${%{$JSXIxml->{JSX}->{ENV}}}{'Path'}) {
            ICSLogger(error,0,"${filePrefix}_I.jsx file MUST specify environment path if checking WSDLs or CONTRACTS.");
            ICSLogger(error,0,"dying now.");
            die;
        }
        my $envInfo  = $JSXIxml->{JSX}->{ENV};
        my $envPath  = $envInfo->{Path};
        my $connPath = $envPath . "/Connector/";
        my $wsdlFileName = $connPath . $icdWsdlTag->{File};
        ICSLogger(debug,2,"ENV OK.");
        
        # File names in DB are FQ
        # File names in ICD should be relative to $envPath/Connector
        # my $select_sql=q{SELECT a.contract_name, a.send_function_id from tbcn_contract a where a.contract_name = '$contractName'};
        my $select_sql="SELECT ct.contract_name, ct.send_function_id, pr.obtain_value FROM tbcn_contract ct, tbcn_parameter pr WHERE ((ct.contract_name = '$contractName') AND (pr.function_id = '$functionID') AND (pr.parameter_index = '$pIndex'))";

        ICSLogger(debug,2,"Preparing query.");
        my $sth1=$dbh->prepare($select_sql);
        ICSLogger(debug,2,"Executing query.");
        my $rc=$sth1->execute;
        ICSLogger(debug,2,"query executed.");
        my ($contract_name, $send_function_id, $obtain_value);
        ICSLogger(debug,2,"Binding columns.");
        if (! $sth1->bind_columns(\($contract_name, $send_function_id, $obtain_value))) {
            ICSLogger(error,0,"Unable to bind_columns: $dbh->errstr");
            ICSLogger(error,0,"dying now.");
            exit;
            die "!!!!!\n";
        };

        ICSLogger(debug,2,"Fetching rows.");
        while ($sth1->fetch) {
            # We need to error out here if more than one row matched this query...
            ICSLogger(debug,2,"OBTAIN_VALUE=\"$obtain_value\"");
            next unless ($obtain_value=~m|file:|);
            $file=($obtain_value=~m|file:(.*)| );
        }
        
        ICSLogger(debug,2,$sth1->rows . " rows fetched.");
        if ($sth1->rows > 1) {
            print "ERROR: Multiple rows returned from query!\n";
            print "       $select_sql\n";
            print "       aborting checkContract for contractName=$contractName and WSDL file=\"$icdWsdlTag->{File}\"\n";
            return;
        }
        
        # Check TBCN_PARAMETER entry for the given function_id / parameter_index
        # update obtain_value with wsdl file name if they do not match.
        ICSLogger(debug,0,"Checking wsdl file name.");
        if ($wsdlFileName eq $file) {
            ICSLogger(info,0,"Contract $contractName has correct wsdl filename ($file)");
        } else {
            ICSLogger(warning,0,"WSDL filename for contract=$contractName does not match DB.");
            ICSLogger(warning,0,"DB contains $file");
            ICSLogger(warning,0,"ICD contains $wsdlFileName");
            ICSLogger(info,0,"Updating TBCN_PARAMETER for FUNCTION_ID=$functionID, PARAMETER_INDEX=$pIndex");
            ICSLogger(info,0,"UPDATE TBCN_PARAMETER SET OBTAIN_VALUE='file:$wsdlFileName' WHERE FUNCTION_ID='$functionID' AND PARAMETER_INDEX = '$pIndex'");
            push (@updateSQL,"UPDATE TBCN_PARAMETER SET OBTAIN_VALUE='file:$wsdlFileName' WHERE FUNCTION_ID='$functionID' AND PARAMETER_INDEX = '$pIndex'");
        }
        
        # Check the TBCN_CONTRACT entry for the given contract_name.
        # update send_function_id with the ICD function id if the do not match.
        ICSLogger(debug,2,"Checking send_function_id.");
        if ($functionID == $send_function_id) {
            ICSLogger(info,0,"SEND_FUNCTION_ID for $contractName matches ICD ($send_function_id)");
        } else {
            ICSLogger(warning,0,"SEND_FUNCTION_ID does not match ICD for $contractName!");
            ICSLogger(warning,0,"DB contains $send_function_id");
            ICSLogger(warning,0,"ICD contains $functionID");
            ICSLogger(info,0,"Updating TBCN_CONTRACT for CONTRACT_NAME=$contractName");
            ICSLogger(info,0,"UPDATE TBCN_CONTRACT set SEND_FUNCTION_ID='$functionID' WHERE CONTRACT_NAME='$contractName'");
            push (@updateSQL,"UPDATE TBCN_CONTRACT set SEND_FUNCTION_ID='$functionID' WHERE CONTRACT_NAME='$contractName'");
        }
        
        # Run the update queries
        ICSLogger(debug,2,": Running updates.");
        my $update;
        foreach $update (@updateSQL) {
        	ICSLogger(info,3,"running update SQL: $update ... ");
            next if (! $update);
            my $sth1=$dbh->prepare($update) or die $dbh->errstr;
            my $rc=$sth1->execute or die $dbh->errstr;
            ICSLogger(debug,3,"completed.");
        }
    }
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}


sub ActiveSpecJACL
{
	checkJMSProcs;
    #---Test----checkBQ;
    #
    # Check the structure of the JSX files.
    validateJSXStructure;
    #
    # generate the jacl file.
    #
    ;
    #
	ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
	my ($node, $srvr, $JMSProvider);
	my @QCFCOptionList = qw(agedTO connTO maxConn minConn pPol reapTime unuTO mapConfAlias);
	#
    # decide the jacl filename
    #
    if ($DELETE) {
        $jaclFile="${cfgDir}/${envPfxI}__JMSKill.jacl";
    } else {
        $jaclFile="${cfgDir}/${envPfxI}__JMSSetup.jacl";
    }
	ICSLogger(info,0,"Generating ${jaclFile}"); 
	if ( ! open(JSSJACL, "> ${jaclFile}")) {
		ICSLogger(error,0,"Could not open JACL output file!");
		die;
	}
	writeJACLHead();
	writeJACLCell();
    processClusActiveSpec;
	
  
    print JSSJACL "\$AdminConfig save\n";
    # print JSSJACL "if {\$dmgr != {}} {\$AdminControl invoke \$dmgr syncActiveNodes Y}\n";
    print JSSJACL "syncAll\n";
    print JSSJACL "exit\n";
    close(JSSJACL);
    ICSLogger(info,0,"Finished generating ${jaclFile}");
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
    execJACL;
		
	
}
sub doJMSSetup {
################################################################################
#
# subroutine : doJMSSetup
# date       : 24 May 2008
# author     : Dan Fitzpatrick
# description: Process ICD for all WebSphere JMS configs.
#
##############################################################################
    ICSLogger(debug,0,"subroutine entry (" . (caller(0))[3] . ")");
    #
    # Make sure JMSProcs.jacl exists in the same location
    #
    checkJMSProcs;
    checkBQ;
    #
    # Check the structure of the JSX files.
    validateJSXStructure;
    #
    # generate the jacl file.
    #
    createJMSDefJACL;
    #
    
    # execute the jacl.
    #
    execJACL;
    ICSLogger(debug,0,"leaving (" . (caller(0))[3] . ")");
}
sub ICSLogSetup {
################################################################################
#
# subroutine : ICSLogSetup
# date       : 24 May 2008
# author     : Dan Fitzpatrick
# description: Preset values for use by ICSLogger
#
################################################################################
    #my $DTStamp = `date +"%Y%m%d-%H%M%S"`;
    my $DTStamp = time();
    chomp $DTStamp;
    my $LFName = "${filePrefix}-ICSetup-${DTStamp}.log";
    open(LOGFILE, "> ${LFName}") || die "ERROR:  Could not open log file (${LFName})\n";
}
sub ICSLogger {
################################################################################
#
# subroutine : ICSLogger
# date       : 24 May 2008
# author     : Dan Fitzpatrick
# description: Takes message and log level and displays/logs as appropriate.
#
################################################################################
    my $logLvl = shift(@_);
    my $logIndent = shift(@_);
        my $logMsg = shift(@_);
        for (my $i=1; $i <= $logIndent; $i++) {
                print LOGFILE "    ";
                print "    ";
        }
        if ($LOGLEVEL >= $logLvl) {
                print LOGFILE "$logPfx[$logLvl]: $logMsg\n";
                ($QUIET) || print "$logPfx[$logLvl]: $logMsg\n";
        }
}

sub ICSLogFini {
    close(LOGFILE);
}



################################################################################
#
#            : Main Program
# date       : 14 February, 2008
# author     : Dan Fitzpatrick
#
################################################################################
#
# Parse the command line...
#
getOpts;
#
# Read the infra jsx file and the ICD file into memory.  Load the ICXml, 
# JSXIxml, and JSXDxml global vars.  These are needed even if not processing
# JMS Setup.
#
getJSX;
#
# Execute the JMS Setup portion, if not suppressed.
#
#($NOJSX) && ICSLogger(info,0,"Skipping JMSSetup.");
#($NOJSX) || doJMSSetup;



#
# Execute the ActivieSpec section , if not suppressed
#


#($NOASP) || ICSLogger(info,0,"Checking for ActiveSpec elements in ICD.");
#(($NOASP)&& ($NOJSX)) || ActiveSpecJACL;
if ( (!$NOASP)||(!$NOJSX) )
{
	if ( (!$NOASP) && (!$NOJSX) )
	{
		doJMSSetup;
	}
	elsif ( (!$NOASP) )
	{
		ActiveSpecJACL
	}
	elsif ( (!$NOJSX) )
	{
		doJMSSetup
	}
}
if ($DELETE) {
	ICSLogger(info,0,"");
	ICSLogger(info,0,"Removal of WebSphere JMS resources is completed.");
	ICSLogger(info,0,"No further processing is allowed when -kill is specified.");
	ICSLogger(info,0,"Exiting.");
    exit;
}
#
# Execute the SpringJMS section, if not suppressed.
#
($NOSPRING) || ICSLogger(info,0,"Checking for SpringJMS elements in ICD.");
($NOSPRING) || doSpringFile;
print "\n\n";
print "########################## Final Results ###################################\n";
if ($wsadminResult>0)
{
  print color 'bold red';
	ICSLogger(error,0,"JSX/ASP Failed Check the Logs for more Info.\n");
	print color 'reset';
}
else
{
  print color 'bold green';
	ICSLogger(info,0,"Script Execution Completed.");
	print color 'reset';
}
print "############################################################################\n";
