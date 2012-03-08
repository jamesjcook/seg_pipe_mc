# command_line.pm
#
# utilities for reading command line 
#
# created 09/10/30  Sally Gewalt CIVM
#                   based on radish pipeline
# 09/10/30 slg
# 11/01/21 slg Add cmd line options to change directories for canonical labels.

# be sure to change version:
my $VERSION = "11/1/21";

#use File::Path;
use strict;
#use English;
use Getopt::Std;

my $NREQUIRED_ARGS = 5;
my $SHOW = 0;

sub command_line {
  # exit with usage message (from your main) if problem detected
  ####my (@ARGV) = @_;

  if ($#ARGV+1 == 0) { usage_message("");}

  print "unprocessed: @ARGV\n";
  my %options = ();
  if (! getopts('ds:b:fzi:l:', \%options)) {
    print "Problem with command line options.\n";
    usage_message("problem with getopts");
  }
  #print "$#ARGV+1 vs $NREQUIRED_ARGS\n";
  #print "processed: @ARGV\n";
  if ($#ARGV+1 < $NREQUIRED_ARGS) { usage_message("Too few arguments on command line");}
  if ($#ARGV+1 > $NREQUIRED_ARGS) { usage_message("Too many arguments on command line");}

  # -- handle required params
  my $cmd_line = "";
  foreach my $a (@ARGV) {  # save the cmd line for annotation
    my $cmd_line = $cmd_line . " " . $a;
  }
  my @arg_list = ();

    if ($#ARGV < 0) {usage_message("Missing required argument on command line");}
  push @arg_list, (shift @ARGV);
  print "@arg_list :T1\n" if $SHOW;
    if ($#ARGV < 0) {usage_message("Missing required argument on command line");}
  push @arg_list, (shift @ARGV);
  print "@arg_list :T2W\n" if $SHOW;
    if ($#ARGV < 0) {usage_message("Missing required argument on command line");}
  push @arg_list, (shift @ARGV);
  print "@arg_list :T2star\n" if $SHOW;
    if ($#ARGV < 0) {usage_message("Missing required argument on command line");}
  push @arg_list, (shift @ARGV);
  print "@arg_list :source subproject\n" if $SHOW;
    if ($#ARGV < 0) {usage_message("Missing required argument on command line");}
  push @arg_list, (shift @ARGV);
  print "@arg_list :dest subproject\n" if $SHOW;

  #  -- handle cmd line options...

  my $flip_y = 0;
  if (defined $options{f}) {  # -f
     $flip_y = 1;
     $cmd_line =  "-f " . $cmd_line;
     print STDERR "  Flipping input images in y. (-f)\n";
  }
  else {
     $flip_y = 0;
     print STDERR "  Not flipping input images in y.\n";
  }
  push @arg_list, $flip_y;

  my $flip_z = 0;
  if (defined $options{z}) {  # -z
     $flip_z = 1;
     $cmd_line =  "-z " . $cmd_line;
     print STDERR "  Flipping input images in z. (-z)\n";
  }
  else {
     $flip_z = 0;
     print STDERR "  Not flipping input images in z.\n";
  }
  push @arg_list, $flip_z;

  my $data_pull = 1;
  if (defined $options{d}) {  # -d
     $data_pull = 0;
     $cmd_line =  "-d " . $cmd_line;
     print STDERR "  No image data to be copied from archive. Data should be available. (-d)\n";
  }
  else {
     $data_pull = 1;
     print STDERR "  Copying image data from archive.\n";
  }
  push @arg_list, $data_pull;
  print "@arg_list :data_pull\n" if $SHOW;

  my $extra_runno_suffix = "--NONE";
  if (defined $options{s}) {  # -s
     $extra_runno_suffix = $options{s};
     print STDERR "  Adding your suffix to result runno: $extra_runno_suffix (-s)\n";
  }
  push @arg_list, $extra_runno_suffix;
  print "@arg_list :extra runno suffix\n" if $SHOW;

  my $bit_mask = "11111";
  if (defined $options{b}) {  # -b
     $bit_mask = $options{b};
     print STDERR "  go bitmask: $bit_mask (set with -b)\n";
  }
  push @arg_list, $bit_mask;
  print "@arg_list :do mask\n" if $SHOW;

  my $label_dir = "DEFAULT";
  if (defined $options{l}) {  # -l
     $label_dir = $options{l};
  }
  push @arg_list, $label_dir;
  print "@arg_list :label_dir\n" if $SHOW;

  my $images_dir = "DEFAULT"; # canonical images dir
  if (defined $options{i}) {  # -i
     $images_dir = $options{i};
  }
  push @arg_list, $images_dir;
  print "@arg_list :images_dir\n" if $SHOW;

if (0) { # example with options....
  my $use_gui_paramfile_boolean;
  if (defined $options{p}) {  # -p
     my $radish_option_string .=  "-p $options{p} ";
     my $gui_paramfile = $options{p};
     $use_gui_paramfile_boolean = 1;
  }
  else {
     $use_gui_paramfile_boolean = 0;
  }
}

  return (@arg_list);
}

1;
