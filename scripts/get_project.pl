#!/usr/bin/env perl
# Ensure it runs on RHEL5
use 5.008_008;
use strict;
use Getopt::Std;
use Pod::Usage;

my $currDir=`pwd`;
chomp $currDir;
my $update=0;

if ($ARGV[0] eq "-u"){
    $update=1;
    shift;
}

my ($projBase, $proj, $scm, $ver, $url)=@ARGV;
my $projDir="$projBase/$proj";
my $clone_action="";
my $update_action="";

if ($scm eq "git"){
    $clone_action="git clone";
    $update_action="git pull";
}elsif($scm eq "svn"){
    $clone_action="svn co";
    $update_action="svn up";
}

if (-d "${projDir}/$ver"){
    if ($update == 1){
	print "    ${projDir}/$ver exists, updating.\n";
	system("cd ${projDir}/$ver;$update_action");
    }
}else{
    print "    ${projDir}/$ver does not exist, clone now.\n";
    system("$clone_action $url $projDir/$ver");
    if ($scm eq "git"){
	unless ($ver eq "master"){
	    system("cd ${projDir}/$ver;git checkout origin/${ver} --track -b $ver");
	}
    }
}

