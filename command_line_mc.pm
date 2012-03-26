# command_line_mc.pm
# reads command line options for seg_pipe_mc, should probably be renamed to 
# reflect that it is specific to the pipe calling it.
# also contains ussage_message for its pipeline
#
# 12/03/08 jjc29 modified option vars to make more sence and match once used 
#          in other sally style perl scripts,   -d changed to -e
#                                               -f changed to -y so it matches -z 
#          added example ussage under command_line so its more clear how this 
#          is used and what it does
# 11/01/21 slg Add cmd line options to change directories for canonical labels.

# created 09/10/30  Sally Gewalt CIVM
#                   based on radish pipeline

# be sure to change version:
my $VERSION = "11/1/21";

#use File::Path;
use strict;
#use English;
use Getopt::Std;
# grab the variables from the seg_pipe.pm file in the script directory, all shared globals stored there, needs full testing to determine functionality
use seg_pipe; # pipe info variable definitions
use label_brain_pipe; # test_mode variable definiton
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT $test_mode);


my $NREQUIRED_ARGS = 3;
my $MAX_ARGS = 5;
my $debug_val = 5;

# ------------------
sub usage_message_mc_hardcodechannels {
# ------------------
# $PIPELINE_VERSION, $PIPELINE_NAME, $PIPELINE_DESC
  my ($msg) = @_;
  print STDERR "$msg\n";
  print STDERR "$PIPELINE_NAME
  $PIPELINE_DESC
usage:
  seg_pipe \<options\> runno_T1  runno_T2W  runno_T2star  subproj_inputs  subproj_result
    required args:
     runno_T1_set     : runno of the input T1 image set (must be available in the archive). 
     runno_T2W_set    : runno of the input T2W image set.
     runno_T2star_set : runno of the input T2star image set. 
     subproj_inputs   : the subproject the input runnos were collected for (and archived under). 
     subproj_result   : the subproject associated with and for storing (image, label) results of this program. 
   options:
     -e         : if used, the runnos will not be copied from the archive (they must be present).
     -y         : if used, input images will be flipped in y before use
     -z         : if used, input images will be flipped in z before use
     -s  suffix : optional suffix on default result runno (doc test params?). Must be ok for filename embed. 
     -l  dir    : change canonical labels directory from default
     -i  dir    : change canonical images directory from default
     -b do_bit_mask : default: 11111 to do all 5 steps; 01111 to skip first step, etc. Steps: nifti, register, strip, whs, label.
                      Skipping is only from gross testing of commands created and not guaranteed to produce results.

version: $PIPELINE_VERSION 

"; 
  exit (! $GOODEXIT);
}
# ------------------
sub usage_message_mc {
# ------------------
# $PIPELINE_VERSION, $PIPELINE_NAME, $PIPELINE_DESC
  my ($msg) = @_;
  print STDERR "$msg\n";
  print STDERR "$PIPELINE_NAME
  $PIPELINE_DESC
usage:
  seg_pipe \<options\> runno_channel1  [runno_channel2]  [runno_channel3]  subproj_inputs  subproj_result
    required args:
     runno_channel1_set : runno of the input channel1, default is a T1 image set (must be available in the archive). 
     runno_channel2_set : runno of the input channel2, default is a T2W image set. (optional)
     runno_channel3_set : runno of the input channel3, default is a T2star image set. (optional)
     subproj_inputs     : the subproject the input runnos were collected for (and archived under). 
     subproj_result     : the subproject associated with and for storing (image, label) results of this program. 
   options:
     -c         : Comma list of channels. The default is T1,T2W,T2star. Suppored channels T1,T2W,T2star,adc,dwi,e1,fa
     -e         : if used, the runnos will not be copied from the archive (they must be present).
     -y         : if used, input images will be flipped in y before use
     -z         : if used, input images will be flipped in z before use
     -s  suffix : optional suffix on default result runno (doc test params?). Must be ok for filename embed. 
     -l  dir    : change canonical labels directory from default
     -i  dir    : change canonical images directory from default
     -b do_bit_mask : default: 11111 to do all 5 steps; 01111 to skip first step, etc. Steps: nifti, register, strip, whs, label.
                      Skipping is only from gross testing of commands created and not guaranteed to produce results.

version: $PIPELINE_VERSION 

"; 
  exit (! $GOODEXIT);
}

sub command_line_mc {
# ex call 
#my ($runno_t1_set, $runno_t2w_set, $runno_t2star_set, 
#    $subproject_source_runnos, $subproject_segmentation_result, 
#    $flip_y, $flip_z, $pull_source_images, $extra_runno_suffix, $do_bit_mask, 
#    $canon_labels_dir, $canon_images_dir) 
#       = command_line(@ARGV);

  # exit with usage message (from your main) if problem detected
  ####my (@ARGV) = @_;

  if ($#ARGV+1 == 0) { usage_message_mc("");}

  print "unprocessed args: @ARGV\n" if ($debug_val >=35);;
  my %options = ();
  if (! getopts('oes:b:yztc:i:l:', \%options)) {
    print "Problem with command line options.\n";
    usage_message_mc("problem with getopts");
  } 
  #print "$#ARGV+1 vs $NREQUIRED_ARGS\n";
  #print "processed: @ARGV\n";
  if ($#ARGV+1 < $NREQUIRED_ARGS) { usage_message_mc("Too few arguments on command line"); }
  if ($#ARGV+1 > $MAX_ARGS) { usage_message_mc("Too many arguments on command line"); }

  # -- handle required params
  my $cmd_line = "";
  foreach my $a (@ARGV) {  # save the cmd line for annotation
    my $cmd_line = $cmd_line . " " . $a;
  }
#  my @arg_list = ();
  my %arg_hash ;
  my $projlist='';
  my $runnolist='';

  if ($#ARGV < 0) { usage_message_mc("Missing required argument on command line"); }
  my $projdest=pop @ARGV;
  if ($#ARGV < 0) { usage_message_mc("Missing required argument on command line"); }
  my $projsource=pop @ARGV;
  $projlist= $projsource . ',' . $projdest ;
  print "$projlist : projin,projout\n" if ($debug_val>=45);
#  unshift @arg_list,$projlist; #prepend projlist
  $arg_hash{projlist}=$projlist;
  
  if ($#ARGV < 0) { usage_message_mc("Missing required argument on command line"); }
  $runnolist=shift @ARGV;
  while( $#ARGV>=0 ) { $runnolist=$runnolist . ',' . shift @ARGV ; } # dump optionally infinite runno's here.
  $arg_hash{runnolist}=$runnolist;

  #  -- handle cmd line options...
  ## single letter opts
  my @singleopts = (); 
#  my $test_mode = 0; # this is world global, so thisi s not appropriate
  if (defined $options{t}) { #-t   testmode
      $test_mode = 1;
      push @singleopts,'t';
      print STDERR " TESTMODE enabled, will do very fast(incomplete) ANTS calls! (-t)\n" if ($debug_val>=10);
#      $debug_val=45;
  }
  print "testmode:$test_mode\n" if ($debug_val>=45); 
  
  my $flip_y = 0;
  if (defined $options{y}) {  # -y
     $flip_y = 1;
     push @singleopts,'y';
#     $cmd_line =  "-y " . $cmd_line;
     print STDERR "  Flipping input images in y. (-y)\n" if ($debug_val>=10);
  } else {
     $flip_y = 0;
     print STDERR "  Not flipping input images in y.\n" if ($debug_val>=10);
  }
  $arg_hash{flip_y}=$flip_y;

  my $flip_z ;
  if (defined $options{z}) {  # -z
     $flip_z = 1;
      push @singleopts,'z';
#     $cmd_line =  "-z " . $cmd_line;
     print STDERR "  Flipping input images in z. (-z)\n" if ($debug_val>=10);
  } else {
     $flip_z = 0;
     print STDERR "  Not flipping input images in z.\n" if ($debug_val>=10);
  }
  $arg_hash{flip_z}=$flip_z;
  
  my $data_pull ;
  if (defined $options{e}) {  # -e
     $data_pull = 0;
     push @singleopts,'e';
     #$cmd_line =  "-e " . $cmd_line;
     print STDERR "  No image data to be copied from archive. Data should be available. (-e)\n" if ($debug_val>=10);
  } else {
     $data_pull = 1;
     print STDERR "  Copying image data from archive.\n" if ($debug_val>=10);
  }
  $arg_hash{data_pull}=$data_pull;

  ##opts with arguments
  my $channel_order='T1,T2W,T2star';
  if (defined $options{c}) {  # -c 
      $channel_order = $options{c};
      $cmd_line = "-c $channel_order " . $cmd_line;
  } else { 
      print STDERR "  Using default channel order $channel_order\n" if ($debug_val>=10);
  }
  $arg_hash{channel_order}=$channel_order;

  my $extra_runno_suffix = "--NONE";
  if (defined $options{s}) {  # -s
     $extra_runno_suffix = $options{s};
     $cmd_line = " -s $extra_runno_suffix " . $cmd_line;
     print STDERR "  Adding your suffix to result runno: $extra_runno_suffix (-s)\n" if ($debug_val>=10);
  }
  $arg_hash{extra_runno_suffix}=$extra_runno_suffix;

  my $bit_mask = "11111";
  if (defined $options{b}) {  # -b
     $bit_mask = $options{b};
     $cmd_line = "-b $bit_mask " . $cmd_line;
     print STDERR "  go bitmask: $bit_mask (set with -b)\n" if ($debug_val>=10);
  }
  $arg_hash{bit_mask} = $bit_mask;

  my $atlas_labels_dir = "DEFAULT";
  if (defined $options{l}) {  # -l
     $atlas_labels_dir = $options{l};
     $cmd_line = "-l $atlas_labels_dir " . $cmd_line;
  }
  $arg_hash{atlas_labels_dir}=$atlas_labels_dir;

  my $atlas_images_dir = "DEFAULT"; # canonical images dir
  if (defined $options{i}) {  # -i
     $atlas_images_dir = $options{i};
     $cmd_line = "-i $atlas_labels_dir " . $cmd_line;
  }
  $arg_hash{atlas_images_dir}=$atlas_images_dir;

  $cmd_line = "-" . join('',@singleopts). $cmd_line;


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
  
#   for my $k (keys %arg_hash) {
#       print "$k: $arg_hash{$k}\n";
#   }
  $arg_hash{cmd_line}=$cmd_line;
  return (\%arg_hash); # makes sure to return a ref, this makes live easier.
}

1;
