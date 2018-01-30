#!/usr/bin/perl
#

use strict;
use POSIX qw(strftime);
use File::Copy;
use File::Path;
use File::Basename;
#use Env;
use Getopt::Std;
use DirHandle;

# Get the release name ,database, schema,password
my ( $opt_r, $opt_mode, $opt_db, $opt_dbs, $opt_dbp) = @ARGV;
my $argCount = $#ARGV +1;

# Set the variable for the export directory

my $pwd    = qx/pwd/;
my $pwdC   = chomp $pwd;
#logMessage("pwd is $pwd\n");
my $deployDIR = $pwd . "/releases\/$opt_r";
logMessage("deployDIR is $deployDIR\n");
# Setup and initialise variables for logging
my $ds     = strftime ("%y%m%d%H%M%S", localtime);
#logMessage("ds is $ds\n");
my $logDir = "$deployDIR" . "/Log";
#logMessage("logDir is $logDir\n");
my $logStream = $logDir . "/DbDeploy" . "\." . $opt_r . "\." . $ds .  "\." . "log";
# will change for each export
my $changeRequestNo = $opt_r;

# Initialise variables
my $jobListFile ="";
my $job ="";
my $sqlexe ="";
my $sqlscript ="";
my $errorCount = 0;
my $deployCount = 0;
my $testCount = 0;
my $backoutCount  = 0;
my $botCount = 0;
my $errorCount  = 0;
my $errorCountDeploy = 0;
my $errorCountTest = 0;
my $errorCountBO = 0;
my $errorCountBOT = 0;
my $change = "";
my $obj = "";
my $name = "";
my $scriptName = "";
my $scriptPath = "";
my @jobs = ();
my %files = ();
my %passSql  = ();
my %allSqlFEAR  = ();
my %applySqlFEAR = ();
my @returnArray = ();
my @sortedSqlFEAR = ();

# start the main processing
mainExpProcessing();

# Write final log messahr
logMessage("Log file is $logStream\n");

##################################### SUBROUTINE DEFINITIONS #########################################
sub logMessage {
   # This subroutine prints out the message to the screen and appends it to the log file
   system "printf \"@_\n\" | tee -a $logStream";
} 

sub mainExpProcessing {

    # Make sure the log directory has been created and start logging
    mkpath ("$deployDIR/Log", 0, 0777);

    logMessage("\nLog file is $logStream\n");
    logMessage("Change Request is $opt_r\n");
    logMessage("Mode is $opt_mode\n") ;
    logMessage("Database is $opt_db\n");
    logMessage("Database schema is $opt_dbs\n");

    if ( $argCount <5 )
    {
        logMessage("\nUsage: FEARdeploy.pl <ChangeRequest> <Mode> <Database> <Schema> <Password> \n");
        die "\n\tMissing Parameters. Aborting.\n\n\t$0 ";
    }

    # Find what needs to be exported
    # This subroutine finds all the objects that needs to be exported from a list of the jobs
    # Build the lists of objects that need to be exported

    # sql scripts

    $jobListFile = $deployDIR . "\/DBchangesToDeploy.txt";
    @jobs = qx/cat $jobListFile/;

    foreach $obj (@jobs) {

        $scriptName = $obj;
        $allSqlFEAR{$scriptName} = $scriptName;
        logMessage("$scriptName");
     } 

     # Sort DB Scripts
     my $size = scalar(keys %allSqlFEAR);
     if ($size > 0) {

        %passSql = %allSqlFEAR;
        sortSQL();
        @sortedSqlFEAR = @returnArray;

        foreach $sqlscript (@sortedSqlFEAR)
        {
            if ( $opt_mode eq "ALL"
                 || $opt_mode eq "DEPLOY" && $sqlscript =~ m/deploy.sql/
                 || $opt_mode eq "TEST" && $sqlscript =~ m/_test.sql/      
                 || $opt_mode eq "BACKOUT" && $sqlscript =~ m/_bo.sql/
                 || $opt_mode eq "BACKOUTTEST" && $sqlscript =~ m/_bot.sql/
                ) 
            { 
                logMessage("\nRunning... sqlplus -s $opt_dbs\/<PASSWORD>\@$opt_db \@$deployDIR\/sql\/$sqlscript;");
                $sqlexe = qx/ sqlplus -s $opt_dbs\/$opt_dbp \@$deployDIR\/sql\/$sqlscript/;
                logMessage ("$sqlexe");
                if ($sqlexe =~ m/ERROR/){

                   logMessage("$sqlscript has errors.");
                   $errorCount = $errorCount +1;

                   if ($sqlscript =~ m/deploy.sql/) {
                       $errorCountDeploy = $errorCountDeploy +1;
                   }
                   elsif ($sqlscript =~ m/_test.sql/) {
                       $errorCountTest = $errorCountTest +1;
                   }
                   elsif ($sqlscript =~ m/_bo.sql/) {
                       $errorCountBO = $errorCountBO +1;
                   }
                   elsif ($sqlscript =~ m/_bot.sql/) {
                       $errorCountBOT = $errorCountBOT +1;
                   }
               }
            }
            else
            { 
                logMessage("\nSkipping... $sqlscript");
            }
        }

		
        logMessage("\nNo. of deploy errors     = $errorCountDeploy");
        logMessage("No. of test errors         = $errorCountTest" ) ;
        logMessage("No. of backout errors      = $errorCountBO");
        logMessage("No. of backout test errors = $errorCountBOT");
        logMessage("Total NO. of errors = $errorCount");

		die "\n\There are $errorCount errors in the $opt_r release.\n\n\t$0 " if ($errorCount > 0);

	}		
}


sub sortSQL {
       # This subroutine sorts the sql that needs to be applied to the database

       # Initialise local arrays

       my @seq = ();
       my @tab = ();
       my @idx = ();
       my @ind = ();
       my @head = ();
       my @view = ();
       my @pack = ();
       my @trig = ();
       my @val = ();
       my @misc = ();
       my @type = ();

       my @seq_t = ();
       my @tab_t = ();
       my @idx_t = ();
       my @ind_t = ();
       my @head_t = ();
       my @view_t = ();
       my @pack_t = ();
       my @trig_t = ();
       my @val_t = ();
       my @misc_t = ();
       my @type_t = ();

       my @seq_bo = ();
       my @tab_bo = ();
       my @idx_bo = ();
       my @ind_bo = ();
       my @head_bo = ();
       my @view_bo = ();
       my @pack_bo = ();
       my @trig_bo = ();
       my @val_bo = ();
       my @misc_bo = ();
       my @type_bo = ();

       my @seq_bot = ();
       my @tab_bot = ();
       my @idx_bot = ();
       my @ind_bot = ();
       my @head_bot = ();
       my @view_bot = ();
       my @pack_bot = ();
       my @trig_bot = ();
       my @val_bot = ();
       my @misc_bot = ();
       my @type_bot = ();


       # Cycle through the list of sql to be applied
       # and add it to the appropriate array
       foreach my $script (sort keys %passSql) {

           chomp($script);

           if ($script =~ m/deploy.sql/)
           { 
              if ($script =~ m/seq/) { push (@seq , $script); }
              elsif ($script =~ m/tab/) { push (@tab, $script); }
              elsif ($script =~ m/idx/) { push (@idx, $script); }
              elsif ($script =~ m/ind/) { push (@ind, $script); }
              elsif ($script =~ m/head/) { push (@head, $script); }
              elsif ($script =~ m/view/) { push (@view, $script); }
              elsif ($script =~ m/pack/) { push (@pack, $script); }
              elsif ($script =~ m/trig/) { push (@trig, $script); }
              elsif ($script =~ m/val/) { push (@val, $script); }
              elsif ($script =~ m/type/) { push (@type, $script); }
              else { push (@misc, $script); }

              $deployCount = $deployCount + 1;
            }
           elsif ($script =~ m/_test.sql/)
           { 
              if ($script =~ m/seq/) { push (@seq_t , $script); }
              elsif ($script =~ m/tab/) { push (@tab_t, $script); }
              elsif ($script =~ m/idx/) { push (@idx_t, $script); }
              elsif ($script =~ m/ind/) { push (@ind_t, $script); }
              elsif ($script =~ m/head/) { push (@head_t, $script); }
              elsif ($script =~ m/view/) { push (@view_t, $script); }
              elsif ($script =~ m/pack/) { push (@pack_t, $script); }
              elsif ($script =~ m/trig/) { push (@trig_t, $script); }
              elsif ($script =~ m/val/) { push (@val_t, $script); }
              elsif ($script =~ m/type/) { push (@type_t, $script); }
              else { push (@misc, $script); }

              $testCount = $testCount + 1;
            }
           elsif ($script =~ m/_bo.sql/)
           { 
              if ($script =~ m/seq/) { push (@seq_bo , $script); }
              elsif ($script =~ m/tab/) { push (@tab_bo, $script); }
              elsif ($script =~ m/idx/) { push (@idx_bo, $script); }
              elsif ($script =~ m/ind/) { push (@ind_bo, $script); }
              elsif ($script =~ m/head/) { push (@head_bo, $script); }
              elsif ($script =~ m/view/) { push (@view_bo, $script); }
              elsif ($script =~ m/pack/) { push (@pack_bo, $script); }
              elsif ($script =~ m/trig/) { push (@trig_bo, $script); }
              elsif ($script =~ m/val/) { push (@val_bo, $script); }
              elsif ($script =~ m/type/) { push (@type_bo, $script); }
              else { push (@misc, $script); }

              $backoutCount = $backoutCount + 1;
            }
           elsif ($script =~ m/_bot.sql/)
           { 
              if ($script =~ m/seq/) { push (@seq_bot , $script); }
              elsif ($script =~ m/tab/) { push (@tab_bot, $script); }
              elsif ($script =~ m/idx/) { push (@idx_bot, $script); }
              elsif ($script =~ m/ind/) { push (@ind_bot, $script); }
              elsif ($script =~ m/head/) { push (@head_bot, $script); }
              elsif ($script =~ m/view/) { push (@view_bot, $script); }
              elsif ($script =~ m/pack/) { push (@pack_bot, $script); }
              elsif ($script =~ m/trig/) { push (@trig_bot, $script); }
              elsif ($script =~ m/val/) { push (@val_bot, $script); }
              elsif ($script =~ m/type/) { push (@type_bot, $script); }
              else { push (@misc, $script); }

              $botCount = $botCount + 1;
           }
		   
         }

         logMessage("\nNo. of dep1oy scripts       = $deployCount");
         logMessage("No. of test scripts         = $testCount");
         logMessage("No. of backout scripts      = $backoutCount");
         logMessage("No. of backout test scripts = $botCount");
         # Create one unified array of sql in sort order
         push (@returnArray, @seq);
         push (@returnArray, @tab);
         push (@returnArray, @type);
         push (@returnArray, @ind);
         push (@returnArray, @idx);
         push (@returnArray, @head);
         push (@returnArray, @view);
         push (@returnArray, @pack);
         push (@returnArray, @trig);
         push (@returnArray, @val);
         push (@returnArray, @misc);

         push (@returnArray, @seq_t);
         push (@returnArray, @tab_t);
         push (@returnArray, @type_t);
         push (@returnArray, @ind_t);
         push (@returnArray, @idx_t);
         push (@returnArray, @head_t);
         push (@returnArray, @view_t);
         push (@returnArray, @pack_t);
         push (@returnArray, @trig_t);
         push (@returnArray, @val_t);
         push (@returnArray, @misc_t);

         #Backout in reverse order
         push (@returnArray, @misc_bo);
         push (@returnArray, @val_bo);
         push (@returnArray, @trig_bo);
         push (@returnArray, @pack_bo);
         push (@returnArray, @view_bo);
         push (@returnArray, @head_bo);
         push (@returnArray, @idx_bo);
         push (@returnArray, @ind_bo);
         push (@returnArray, @type_bo);
         push (@returnArray, @tab_bo);
         push (@returnArray, @seq_bo);

		 
         push (@returnArray, @seq_bot);
         push (@returnArray, @tab_bot);
         push (@returnArray, @type_bot);
         push (@returnArray, @ind_bot);
         push (@returnArray, @idx_bot);
         push (@returnArray, @head_bot);
         push (@returnArray, @view_bot);
         push (@returnArray, @pack_bot);
         push (@returnArray, @trig_bot);
         push (@returnArray, @val_bot);
         push (@returnArray, @misc_bot);

}