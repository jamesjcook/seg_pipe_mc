# command_line_mc.pm
# reads command line options for seg_pipe_mc, 
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
my $VERSION = "20130730";

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
#my $MAX_ARGS = 5;
my $debug_val = 5;

# ------------------
sub usage_message_mc {
# ------------------
# $PIPELINE_VERSION, $PIPELINE_NAME, $PIPELINE_DESC
  my ($msg) = @_;
  print STDERR "$msg\n";
  print STDERR "$PIPELINE_NAME
  $PIPELINE_DESC
INPUT:  civmraw from archive.
OUTPUT: input images as nifti in atlas space, with 8-bit nifti labels.
NOTE: For nifti inputs see the example directory in hostnamespace.
usage:
  seg_pipe \<options\> runno_channel1  [runno_channel2]  [runno_channel3]  subproj_inputs  subproj_result
    required args:
     runno_channel1_set : runno of the input channel1, default is a T1 image set 
                          (all must be available in the archive). 
     runno_channel2_set : runno of the input channel2, default is a T2W image set. (optional)
                          (all must be available in the archive). 
     runno_channel3_set : runno of the input channel3, default is a T2star image set. (optional)
                          (all must be available in the archive). 
     subproj_inputs     : source subprojcet, subproject the input runnos were archived under.
                          ex 00.anything.00  (format is ##.<text>.##  or ([0-9]{2}[.]\w[.][0-9]{2}) )
     subproj_result     : destination subproject, subproject for the results (image, label) under. 
                          ex 00.anything.00
   options (all options are optional):
     -q             : Channel queue. A coma separated list of channels. 
                      The default is T1,T2W,T2star. Suppored channels T1,T2W,T2star,adc,dwi,e1,fa
     -e             : Data exists locally, the data will not be copied from the archive.
     -c             : Coil Bias enable, N4 coil bias will be calculated and applied to all input.
                      NOTE: must be set for the bit mask value to have meaning. 
     -n  type       : Noise Correction, must specify type ex -n SUSAN, OR -n Bilateral,
                      NOTE: must be set for the bit mask value to have meaning. 
     -x             : rorate to flip x, all input images will be rotated along y to flip x before use (this happens before niftify).
     -z             : rotate to flip z, all input images will be rotated along x to flip z before use (this happens before niftify).
     -r <n1:n2>     : rolling value to be used on the convert to nifti step, x:y roll. 
     -s <n1-n2>     : slice crop, value 1 is the first slice include, value 2 is the last slice included. 
                      Can be used to do a Z flip(not rotate) by using bigger number first.
                      ex 50-450     would only include slices 50-450
     -p             : Port atlas mask. Will generate a skull mask with the input dataset and use that to guide a 
                      registration of the atlas mask. The registered atlas mask will be used for skull stripping.
     -k             : Advanced option for masking,
                      use existing mask file named \"runno_channel1_manual_mask.nii\" in the work directory on disk.
     -m  channels   : Channels considered for registration, Default 2, if more than this number 
                      of channels is specified they will not be used for registration, and will
                      have just the transforms applied. 
     --suffix=suffix: Optional suffix for output directory, 
                      WARNING: letters, numbers or underscore ONLY([a-zA-Z_0-9]). 
     --threshold=theshold_code
                    : the threshold_code to use in the matlab strip_mask.m function
                      100-inf manual value
                      1-99 threshold-zero from derivative histogram
                      -1  manual selection using imagej
     -l  dir        : Label directory, default is set in setup files. 
                      Directory must contain <atlas_id>_labels.nii files, use -a (see below).
     -i  dir        : Registration Target, default is set in setup files. 
                      Directory must contain <atlas_id>_<channel>.nii files, use -a (see below).
     -a  atlas_id   : Atlas_id tag for custom atlas, ONLY USED with -i option otherwise ignored.
                      Specifies the atlas_id part of the filename, \"whs\" for waxholmspace atlas,
                      otherwise defautls to \"atlas\".
     -b do_bit_mask : Step skipping, default: 11111111 to do all 8 steps; 01111111 to skip first step, etc. 
                      MUST ALWAYS USE 8 DIGITS, LESS DIGITS WILL GIVE UNEXPECTED RESULTS!
                      Steps: 
                      \tnifti,    - take civm raw format images and turn them into nifti.
                      \tbias,     - bias correction enabled with -c option.
                      \tnoise,    - noise correction enabled with -n option, ignored if -n not specified
                      \treg_ch1,  - rigid register to first channel
                      \tstrip,    - skull strip calculation for first channel(applied ot all)
                      \treg_atlas,- rigid register to atlas
                      \tlabel,    - diffeomorphic register atlas label to image in atlas space.
                      \tvolumecalc.- calculate volumes of labels 
                      Skipping is only for gross testing of commands created and not guaranteed to produce results.
     -t             : test mode, cuts all iterations for ants to 1x0x0x0, really fun with bit mask for rapid code testing. 
                      eg, this option is NOT FOR REGULAR USERS. 
     -d   direction : Optional argument for specifying the direction of registration, default uses inverse
                       use f or i : f forward transforms, i inverse transforms applied to atlas labels (default)

version: $PIPELINE_VERSION 

Examples:
single contrast, with existing data
\tseg_pipe_mc -e E00001 11.test.01 11.test.01
dual contrast, with existing data
\tseg_pipe_mc -e E00001 E00002 11.test.01 11.test.01
dual contrast, with exsiting nii data (using test data set up from the install)
\tseg_pipe_mc -a phant -i /pipe_home/whs_references/phant_images \\
                       -l /pipe_home/whs_references/phant_labels \\
                       -eb 01111111 TESTDATA TESTDATA2 11.test.01 11.test.01
dual contrast, with existing data using non standard contrasts.
\tseg_pipe_mc -a phant -i /pipe_home/whs_references/phant_images \\
                       -l /pipe_home/whs_references/phant_labels \\
                       -q T1,T2W \\
                       -eb 01111111 TESTDATA TESTDATA2 11.test.01 11.test.01
seg_pipe_mc -a DTI -i /Volumes/pipe_home/whs_references/whs_canonical_images/dti_average/ \
                   -l /Volumes/pipe_home/whs_references/whs_labels/dti_average/ \
                   -z -m 2 -q dwi,fa N50883_m0 N50883_m0 13.calakos.01 13.calakos.01

"; 
  exit ( $BADEXIT );
}

sub command_line_mc {
  if ($#ARGV+1 == 0) { usage_message_mc("");}
  print "unprocessed args: @ARGV\n" if ($debug_val >=35);;
  my %options = ();
  if (! getopts('a:b:cd:ei:kl:m:n:opq:r:s:txz-:', \%options)) {
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
#  if ($#ARGV < 0) { usage_message_mc("Missing required argument on command line"); }
#  my $user_id=pop @ARGV;
  my $err;
  # add to the error string unless we have good proj source or dest
  $err ="source project bad format! <$projsource>  " unless( $projsource =~ m/[0-9]{2}[.]\w{1,50}[.][0-9]+/ );
  $err = $err . "destination project bad format!<$projdest>" unless( $projdest =~ m/[0-9]{2}[.]\w{1,50}[.][0-9]+/ );
#   if ($user_id =~ m/[A-Z][0-9]{5,}[\w]*/x ) { # if user matches a runnumber, assumes its an error.
#       my $id_warning="WARNING: no id specified on command line !" ;
#       warn ( $id_warning);
#       push (@ARGV, $user_id) ; 
#       $user_id='UNDEFINED';
#       
#   }
#   $arg_hash{user_id}=$user_id;
  error_out("$err") unless( $err eq '' );

  $projlist= $projsource . ',' . $projdest ;
  print "$projlist : projin,projout\n" if ($debug_val>=45);
  $arg_hash{projlist}=$projlist;
  
  if ($#ARGV < 0) { usage_message_mc("Missing required argument on command line"); }
  $runnolist=shift @ARGV;
  while( $#ARGV>=0 ) { $runnolist=$runnolist . ',' . shift @ARGV ; } # dump optionally infinite runno's here.
  $arg_hash{runnolist}=$runnolist;


  if ($#ARGV >  0 ) { 
      my $argoutstring='';
      for my $arg (@ARGV) {
	  $argoutstring="${argoutstring}\n\t$arg";
      }
      usage_message_mc("Arguments remaining ($#ARGV+1) on command line $argoutstring"); 
  }



  #  -- handle cmd line options...
  ## single letter opts
  my @singleopts = (); 
  
  my $data_pull ;
  if (defined $options{e}) {  # -e
     $data_pull = 0;
     push @singleopts,'e';
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

  my $port_atlas_mask;
  if (defined $options{p}) {  # -p
     $port_atlas_mask = 1;
     push @singleopts,'p';
     print STDERR "  Porting atlas mask via registration to generated.(-p)\n";
  } else {
     $port_atlas_mask = 0;
#     print STDERR "  Port mask disabled\n";
  }
  $arg_hash{port_atlas_mask}=$port_atlas_mask;

  my $use_existing_mask;
  if (defined $options{k}) {  # -k
     $use_existing_mask = 1;
     push @singleopts,'k';
     print STDERR "  Using existing mask named runno_channel1_manual_mask.nii. (-k)\n";
  } else {
     $use_existing_mask = 0;
  }
  $arg_hash{use_existing_mask}=$use_existing_mask;

  if (defined $options{t}) { #-t   testmode
      $test_mode = 1;
      push @singleopts,'t';
      print STDERR "  TESTMODE enabled, will do very fast(incomplete) ANTS calls! (-t)\n" if ($debug_val>=10);
  }
  print "testmode:$test_mode\n" if ($debug_val>=45); 

  
  my $flip_x = 0;
  if (defined $options{x}) {  # -x
     $flip_x = 1;
     push @singleopts,'x';
     print STDERR "  Rotating input images for x. (-x)\n" if ($debug_val>=10);
  } else {
     $flip_x = 0;
     print STDERR "  Not rotating input images for x.\n" if ($debug_val>=10);
  }
  $arg_hash{flip_x}=$flip_x;

  my $flip_z ;
  if (defined $options{z}) {  # -z
     $flip_z = 1;
      push @singleopts,'z';
     print STDERR "  Rotating input images for z. (-z)\n" if ($debug_val>=10);
  } else {
     $flip_z = 0;
     print STDERR "  Not Rotating input images for z.\n" if ($debug_val>=10);
  }
  $arg_hash{flip_z}=$flip_z;
  

  ##opts with arguments
  my $channel_order='T1,T2W,T2star';
  if (defined $options{q}) {  # -q 
      $channel_order = $options{q};
      $cmd_line = "-q $channel_order " . $cmd_line;
  } else { 
      print STDERR "  Using default channel order $channel_order\n" if ($debug_val>=10);
  }
  $arg_hash{channel_order}=$channel_order;


 ##opts with arguments
  my $roll_string='0:0';
  if (defined $options{r}) {  # -r 
      $roll_string = $options{r};
      $cmd_line = "-r $roll_string " . $cmd_line;
      if( $roll_string !~m/^[0-9]+:[0-9]+$/){
	usage_message_mc("  Using roller requires two parameters separated by : no spaces"); 
      }
  } else { 
      print STDERR " No rolliing specified, leaving image in original position $roll_string\n" if ($debug_val>=10);
  }
  $arg_hash{roll_string}=$roll_string;


  my $transform_direction='i';
  if (defined $options{d} ) {  # -d 
    if ( $options{d} eq 'f' || $options{d} eq 'i' ) { 
      $transform_direction = $options{d};
      $cmd_line = "-d $transform_direction " . $cmd_line;
    } else { 
      error_out("Bad transform direction, only f or i is valid.");
    }
  } else { 
    print STDERR "  Using default transform direction $transform_direction\n" if ($debug_val>=10);
  }
  $arg_hash{transform_direction}=$transform_direction;

  my $registration_channels=2;
  if (defined $options{m}) {  # m
     $registration_channels = $options{m};
     $cmd_line =  "-m $registration_channels " . $cmd_line ;
     print STDERR "  Registration channels specified, will use up to ${registration_channels} channels. (-m)\n";
  } else {
     print STDERR "  Registration channels not specified, using up to 2.\n";
  }
  $arg_hash{registration_channels}=$registration_channels;

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

  my $bit_mask = "11111111";
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
     $cmd_line = "-i $atlas_images_dir " . $cmd_line;
     if (defined $options{a}) { # -a 
	 $atlas_id = $options{a};
	 $cmd_line = "-a $atlas_id " . $cmd_line;
     }
  }
  $arg_hash{atlas_images_dir}=$atlas_images_dir;
  $arg_hash{atlas_id}=$atlas_id;


  my $sliceselect;
  if (defined $options{s}) {  # -s
      $sliceselect = $options{s};
      $cmd_line =  "-s $sliceselect " . $cmd_line;
      print STDERR "  Only slices $sliceselect will be used(-s)\n";
  }
  else {
      $sliceselect = "all";
      print STDERR "  Will use all slices.\n";
  }
  $arg_hash{sliceselect}=$sliceselect;

  $arg_hash{threshold_code}=2;
  if (defined $options{'-'}) { # extra ooptsion processing
      my $extra_runno_suffix = "--NONE";  
      my @extended_opts=split(',',$options{'-'});

      for my $opt (@extended_opts) {
	  $options{'-'}=$opt;
	  if ($options{'-'} =~ /^suffix=.*/) {  # --suffix
	      ($options{'-'},$extra_runno_suffix)=split('=',$options{'-'});
	      $extra_runno_suffix=~s/(?:^ +)||(?: +$)//g ;
#	      $extra_runno_suffix = $options{'-'};
	      $cmd_line = " --suffix=$extra_runno_suffix " . $cmd_line;
	      print STDERR "  Adding your suffix to result runno: --suffix=$extra_runno_suffix\n" if ($debug_val>=10);
	      $arg_hash{extra_runno_suffix}=$extra_runno_suffix;
	  } elsif ($options{'-'} =~ /^threshold=.*/) {  # --threshold
	      ($options{'-'},$arg_hash{threshold_code})=split('=',$options{'-'});
	      $cmd_line = " --threshold=$arg_hash{threshold_code} " . $cmd_line;
	      print STDERR "  using thrshold_code: --threshold=$arg_hash{threshold_code}\n" if ($debug_val>=10);
	  } else { 
	      error_out("Un recognized extended option -".$options{'-'}."\n");
	  }
      }

  } 

  $cmd_line = "-" . join('',@singleopts) . " " . $cmd_line;  
   for my $k (keys %arg_hash) {
       print "$k: $arg_hash{$k}\n" if ($debug_val >=35);
   }
  $arg_hash{cmd_line}=$cmd_line;
  return (\%arg_hash); # makes sure to return a ref, this makes life easier.
}

1;
