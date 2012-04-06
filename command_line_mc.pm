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
my $VERSION = "12/04/02";

#use File::Path;
use strict;
#use English;
use Getopt::Std;
# grab the variables from the seg_pipe.pm file in the script directory, all shared globals stored there, needs full testing to determine functionality
use seg_pipe; # pipe info variable definitions
use label_brain_pipe; # test_mode variable definiton
# the use vars line pulls variables deffinitons from any begin block in any module included. 
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT $test_mode );


my $NREQUIRED_ARGS = 3;
my $MAX_ARGS = 5;
my $debug_val = 10;

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
     runno_channel1_set : runno of the input channel1, default is a T1 image set (all must be available in the archive). 
     runno_channel2_set : runno of the input channel2, default is a T2W image set. (optional)(all must be available in the archive). 
     runno_channel3_set : runno of the input channel3, default is a T2star image set. (optional)(all must be available in the archive). 
     subproj_inputs     : source subprojcet, the subproject the input runnos were collected for (and archived under). 
     subproj_result     : destination subproject, the subproject associated with and for storing (image, label) results of this program. 
   options:
     -q             : Channel queue. A coma separated list of channels. The default is T1,T2W,T2star. Suppored channels T1,T2W,T2star,adc,dwi,e1,fa
     -e             : if used, the runnos will not be copied from the archive (they must be present).
     -c             : if used, n4 coil bias will be applied to all input images 
                      NOTE: must be set for the bit mask value to have meaning. 
     -n  type       : if used, noise reduction on, must specify type ex -n SUSAN, OR -n Bilateral, or -n ANTS, 
                      NOTE: must be set for the bit mask value to have meaning. (dont forget the bit-mask changes)
     -y             : if used, input images will be flipped in y before use
     -z             : if used, input images will be flipped in z before use
     -s  suffix     : optional suffix on default result runno (doc test params?). Must be ok for filename embed. 
     -l  dir        : change canonical labels directory from default, directory must contain <atlas_id>_labels.nii files
     -a  atlas_id   : id tag for custom atlas, ONLY USED with -i option otherwise ignored, specifies the atlas_id part of the 
filename, \"whs\" for waxholmspace atlas, otherwise defautls to \"atlas\"
     -i  dir        : change canonical images directory from default, directory must contain <atlas_id>_<channel>.nii files
     -b do_bit_mask : default: 1111111 to do all 6 steps; 011111 to skip first step, etc. Steps: nifti,noise, bias, register, strip, atlas-reg, label, volumecalc.
                      Skipping is only from gross testing of commands created and not guaranteed to produce results.
     -t             : test mode, cuts all iterations for ants to 1x0x0x0, really fun with bit mask for rapid code testing. 
                      eg, this option is NOT FOR REGULAR USERS. 

version: $PIPELINE_VERSION 

"; 
  exit (! $GOODEXIT);
}

sub command_line_mc {
  if ($#ARGV+1 == 0) { usage_message_mc("");}
  print "unprocessed args: @ARGV\n" if ($debug_val >=35);;
  my %options = ();
  if (! getopts('ab:cei:l:n:oq:s:tyz', \%options)) {
    print "Problem with command line options.\n";
    usage_message_mc("problem with getopts");
  } 
  #print "$#ARGV+1 vs $NREQUIRED_ARGS\n";
  #print "processed: @ARGV\n";
  if ($#ARGV+1 < $NREQUIRED_ARGS) { 
      my $argoutstring='';
      for my $arg (@ARGV) {
	  $argoutstring="${argoutstring}\n\t$arg";
      }
      usage_message_mc("Too few arguments($#ARGV+1) on command line $argoutstring"); 
  }
  if ($#ARGV+1 > $MAX_ARGS) { 
      my $argoutstring='';
      for my $arg (@ARGV) {
	  $argoutstring="${argoutstring}\n\t$arg";
      }
      usage_message_mc("Too many arguments($#ARGV+1) on command line $argoutstring"); 
  }

  # -- handle required params
  my $cmd_line = "";
  foreach my $a (@ARGV) {  # save the cmd line for annotation
    my $cmd_line = $cmd_line . " " . $a;
  }
  my %arg_hash ;
  my $projlist='';
  my $runnolist='';  # later it might be nice to set up the runno list to optionally grab a channel from the runno, like <channel_id>CIVMRUNNO 
  if ($#ARGV < 0) { usage_message_mc("Missing required argument on command line"); }
  my $projdest=pop @ARGV;
  if ($#ARGV < 0) { usage_message_mc("Missing required argument on command line"); }
  my $projsource=pop @ARGV;
  my $err;
  # add to the error string unless we have good proj source or dest
  $err ="source project bad format! <$projsource>  " unless( $projsource =~ m/[0-9]{2}[.]\w{1,50}[.][0-9]+/ );
  $err = $err . "destination project bad format!<$projdest>" unless( $projdest =~ m/[0-9]{2}[.]\w{1,50}[.][0-9]+/ );
  error_out("$err") unless( $err eq '' );

  $projlist= $projsource . ',' . $projdest ;
  print "$projlist : projin,projout\n" if ($debug_val>=45);
  $arg_hash{projlist}=$projlist;
  
  if ($#ARGV < 0) { usage_message_mc("Missing required argument on command line"); }
  $runnolist=shift @ARGV;
  while( $#ARGV>=0 ) { $runnolist=$runnolist . ',' . shift @ARGV ; } # dump optionally infinite runno's here.
  $arg_hash{runnolist}=$runnolist;

  #  -- handle cmd line options...
  ## single letter opts
  my @singleopts = (); 
  
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


  my $coil_bias;
  if (defined $options{c}) {  # -c
     $coil_bias = 1;
     push @singleopts,'c';
     print STDERR "  Coil bias will be applied prior to registration. (-c)\n";
  } else {
     $coil_bias = 0;
#     print STDERR "  Coil bias not selected.\n";
  }
  $arg_hash{coil_bias}=$coil_bias;

  if (defined $options{t}) { #-t   testmode
      $test_mode = 1;
      push @singleopts,'t';
      print STDERR "  TESTMODE enabled, will do very fast(incomplete) ANTS calls! (-t)\n" if ($debug_val>=10);
  }
  print "testmode:$test_mode\n" if ($debug_val>=45); 
  
  my $flip_y = 0;
  if (defined $options{y}) {  # -y
     $flip_y = 1;
     push @singleopts,'y';
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
     print STDERR "  Flipping input images in z. (-z)\n" if ($debug_val>=10);
  } else {
     $flip_z = 0;
     print STDERR "  Not flipping input images in z.\n" if ($debug_val>=10);
  }
  $arg_hash{flip_z}=$flip_z;
  
  ##opts with arguments
  my $channel_order='T1,T2W,T2star';
  if (defined $options{c}) {  # -q 
      $channel_order = $options{q};
      $cmd_line = "-q $channel_order " . $cmd_line;
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


  my $noise_reduction;
  if (defined $options{n}) {  # -n
     $noise_reduction = $options{n};
     $cmd_line = " -n $noise_reduction " . $cmd_line;
     print STDERR "  Noise reduction using the $noise_reduction algorithm will be applied prior to registration. (-n)\n";
  }
  else {
     $noise_reduction = "--NONE";
#     print STDERR "  Noise reduction not selected.\n";
  }
  $arg_hash{noise_reduction}=$noise_reduction;

  my $bit_mask = "1111111";
  if (defined $options{b}) {  # -b
     $bit_mask = $options{b};
     while( length("$bit_mask")<7){ 
	 $bit_mask="0".$bit_mask;
     }
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
  my $atlas_id = "DEFAULT";
  if (defined $options{i}) {  # -i
     $atlas_images_dir = $options{i};
     $cmd_line = "-i $atlas_labels_dir " . $cmd_line;
     if (defined $options{a}) { # -a 
	 $atlas_id = $options{a};
	 $cmd_line = "-a $atlas_id " . $cmd_line;
     }
  }
  $arg_hash{atlas_images_dir}=$atlas_images_dir;
  $arg_hash{atlas_id}=$atlas_id;
  $cmd_line = "-" . join('',@singleopts) . " " . $cmd_line;

   for my $k (keys %arg_hash) {
       print "$k: $arg_hash{$k}\n" if ($debug_val >=35);
   }
  $arg_hash{cmd_line}=$cmd_line;
  return (\%arg_hash); # makes sure to return a ref, this makes live easier.
}

1;
