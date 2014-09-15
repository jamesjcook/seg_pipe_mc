# command_line_mc.pm
# reads command line options for seg_pipe_mc, 
# also contains usage_message for its pipeline
#
# 14/08/16 rja20. Integrate Atropos module into pipeline. Replaced all active "STDERR" with "STDOUT".
#
#
# 12/03/08 jjc29 modified option vars to make more sense and match once used 
#          in other sally style perl scripts,   -d changed to -e
#                                               -f changed to -y so it matches -z 
#          added example usage under command_line so its more clear how this 
#          is used and what it does
# 11/01/21 slg Add cmd line options to change directories for canonical labels.

# created 09/10/30  Sally Gewalt CIVM
#                   based on radish pipeline

# be sure to change version:
my $VERSION = "20130730";  ## BJ - UPDATE Need to update version when finished  making changes.

#use File::Path;
use strict;
#use English;
use Getopt::Std;
# grab the variables from the seg_pipe.pm file in the script directory, all shared globals stored there, needs full testing to determine functionality
use seg_pipe; # pipe info variable definitions
use label_brain_pipe; # test_mode variable definiton
use atropos; # handling of atropos parameters
# the use vars line pulls variables deffinitons from any begin block in any module included. 
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT $test_mode );
require Headfile;

my $NREQUIRED_ARGS = 3;
#my $MAX_ARGS = 5;
my $debug_val = 5; ## BJ - revert to "5" when done

my $allowed_atropos_channels;

# ------------------
sub usage_message_mc {
# ------------------
# $PIPELINE_VERSION, $PIPELINE_NAME, $PIPELINE_DESC
  my ($msg,$Hf) = @_;
  my $allowed_channels;
  my @allowed_atropos_channels_array;
  my @allowed_atropos_s_or_p=('','');
  if (($Hf->get_value('calling_program_name')) eq 'main_seg_pipe_mc.pl') {
      $allowed_channels = allowed_channels($Hf,'allowed_channels');
      $allowed_atropos_channels=allowed_channels($Hf,'allowed_atropos_channels');
      if ($allowed_channels) {
	  @allowed_atropos_channels_array = split(',',$allowed_atropos_channels);
	  if ($#allowed_atropos_channels_array < 0) {
	      @allowed_atropos_s_or_p = ('channels','are');
	  } else {
	      @allowed_atropos_s_or_p = ('channel','is');
	  }
      } else {
	  $allowed_channels = 'T1,T2W,T2star,adc,dwi,e1,fa';
	  $allowed_atropos_channels = 'fa';
	  @allowed_atropos_s_or_p = ('channel','is');       
      }
  } else {
       $allowed_channels = 'T1,T2W,T2star,adc,dwi,e1,fa';
       $allowed_atropos_channels = 'fa';
       @allowed_atropos_s_or_p = ('channel','is'); 
  }

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
     subproj_inputs     : source subproject, subproject the input runnos were archived under.
                          ex 00.anything.00  (format is ##.<text>.##  or ([0-9]{2}[.]\w[.][0-9]{2}) )
     subproj_result     : destination subproject, subproject for the results (image, label) under. 
                          ex 00.anything.00
   options (all options are optional):
     -q             : Channel queue. A coma separated list of channels. 
                      The default is T1,T2W,T2star. Supported channels are $allowed_channels.
     -e             : Data exists locally, the data will not be copied from the archive.
     -c             : Coil Bias enable, N4 coil bias will be calculated and applied to all input.
                      NOTE: must be set for the bit mask value to have meaning. 
     -n  type       : Noise Correction, must specify type ex -n SUSAN, OR -n Bilateral,
                      NOTE: must be set for the bit mask value to have meaning. 
     -x             : rotate to flip x, all input images will be rotated along y to flip x before use (this happens before niftify).
     -z             : rotate to flip z, all input images will be rotated along x to flip z before use (this happens before niftify).
     -r <n1:n2>     : rolling value to be used on the convert to nifti step, x:y roll. 
     -s <n1-n2>     : slice crop, value 1 is the first slice include, value 2 is the last slice included. 
                      Can be used to do a Z flip(not rotate) by using bigger number first.
                      ex 50-450     would only include slices 50-450
     -p             : Port atlas mask. Will generate a skull mask with the input dataset and use that to guide a 
                      registration of the atlas mask. The registered atlas mask will be used for skull stripping.
     -k             : Advanced option for masking,
                      use existing mask file named \"runno_channel1_manual_mask.nii\" in the work directory on disk.
     -m  channels   : Channels considered for registration, Default 2, if more than this number of channels is specified
                      and the atropos flag -f is defined then the first extra channel will be used for atropos segmentation.
                      Otherwise extra channels will not be used for registration, and will have just the transforms applied.
     -l  dir        : Label directory, default is set in setup files. 
                      Directory must contain <atlas_id>_labels.nii files, use -a (see below).
     -i  dir        : Registration Target, default is set in setup files. 
                      Directory must contain <atlas_id>_<channel>.nii files, use -a (see below).
     -a  atlas_id   : Atlas_id tag for custom atlas.
                      Specifies the atlas_id part of the filename, \"whs\" for waxholmspace atlas,
                      otherwise defautls to \"atlas\".
     -f atropos_ch  : Run Atropos module for 3-label intensity segmentation and correlation, with channel defined by atropos_ch.
                      Allowed $allowed_atropos_s_or_p[0] for use with Atropos $allowed_atropos_s_or_p[1]: $allowed_atropos_channels.  Currently (as of August 2014), the default parameters
                      produce the following command line  \"                                             \## BJ-- Update 
                      \"
     -u user-defined: Atropos wil run with default parameters.  Any variation of this can be set by calling -u and either specifying
        atropos       a path to a parameter file in \"parameter=value\/n\" format, or calling -u and the custom atropos command line 
        parameters    parameters in double quotations.  For example, to manually set the dimensionality to 4, use : \"-d 4\".  In the
                      latter case it is important to not use any double quotes within the original quotes.  If an invalid file path or
                      string is entered, then Atropos will run with the default values.
     -b do_bit_mask : Step skipping, default: 111111111 to do all 8 steps; 01111111 to skip first step, etc. 
                      MUST ALWAYS USE 9 DIGITS, LESS DIGITS WILL GIVE UNEXPECTED RESULTS! (Except in the case of
                      not calling Atropos, where an 8 digit input will have a zero appended to the end of it.)
                      Steps: 
                      \tnifti,    - take civm raw format images and turn them into nifti.
                      \tbias,     - bias correction enabled with -c option.
                      \tnoise,    - noise correction enabled with -n option, ignored if -n not specified
                      \treg_ch1,  - rigid register to first channel
                      \tstrip,    - skull strip calculation for first channel(applied ot all)
                      \treg_atlas,- rigid register to atlas
                      \tlabel,    - diffeomorphic register atlas label to image in atlas space.
                      \tstat_calc,- calculate statistics of labels 
                      \tatropos.  - run 3-label Atropos segmentation and refine labels via cross-correlation ##BJ - UPDATE
                      Skipping is only for gross testing of commands created and not guaranteed to produce results.
     -t             : test mode, cuts all iterations for ants to 1x0x0x0, really fun with bit mask for rapid code testing. 
                      eg, this option is NOT FOR REGULAR USERS. 
     -d   direction : Optional argument for specifying the direction of registration, default uses inverse
                       use f or i : f forward transforms, i inverse transforms applied to atlas labels (default)
  Extended options: 
   -- designates extened name=value options separated by comas.
   --[OPTIONNAME=OPTIONVALUE,OPTIONNAME2=OPTION2VALUE]
    
     suffix=suffix: Optional suffix for output directory, 
                      WARNING: letters, numbers or underscore ONLY([a-zA-Z_0-9]). 
     threshold=theshold_code
                    : the threshold_code to use in the matlab strip_mask.m function
                      100-inf manual value
                      1-99 threshold-zero from derivative histogram
                      -1  manual selection using imagej
     EX1. --threhsold=2100
     EX2. --suffix=2100
     EX3. --threhsold=2100,suffix=\"testsuffix\"

version: $PIPELINE_VERSION 

Examples:
single contrast, with existing data
\tseg_pipe_mc -e E00001 11.test.01 11.test.01
dual contrast, with existing data
\tseg_pipe_mc -e E00001 E00002 11.test.01 11.test.01
dual contrast, with exsiting nii data (using test data set up from the install)
\tseg_pipe_mc -a phant -i \$WORKSTATION_DATA/atlas/phant_canonical_images \\
                       -l \$WORKSTATION_DATA/atlas/phant_labels \\
                       -eb 01111111 TESTDATA TESTDATA2 11.test.01 11.test.01
dual contrast, with existing data using non standard contrasts.
\tseg_pipe_mc -a phant -i /\$WORKSTATION_DATA/atlas/phant_images \\
                       -l /\$WORKSTATION_DATA/atlas/phant_labels \\
                       -q T1,T2W \\
                       -eb 01111111 TESTDATA TESTDATA2 11.test.01 11.test.01
 rapid test with real data
seg_pipe_mc -ta DTI -i \$WORKSTATION_DATA/atlas/DTI/ \\
                    -l \$WORKSTATION_DATA/atlas/DTI/ \\
                    -z -m 2 -q dwi,fa N50883_m0 N50883_m0 13.calakos.01 13.calakos.01 



"; 
  exit ( $BADEXIT );
}

sub allowed_channels {
    my ($Hf,$key) = @_;
    my $pipeline_parameter_hf_name = 'seg_pipe_parameters.headfile'; # Default location of pipeline parameter file.
    my $pipeline_parameter_hf_path = $Hf->get_value('calling_program_path');
    my $pipeline_parameter_hf_full_path =  $pipeline_parameter_hf_path.'/'.$pipeline_parameter_hf_name;
    if (-e $pipeline_parameter_hf_full_path) {    
	my $pipeline_params = new Headfile ('ro', $pipeline_parameter_hf_full_path);
	$pipeline_params->read_headfile;
	my $allowed_channels = $pipeline_params->get_value($key);
	return ($allowed_channels);
    } else {
	return (0);  # Zero is returned if the pipeline parameters headfile does not exist.
     }
}


sub command_line_mc {
  my ($Hf)=@_;
  if ($#ARGV<=0) { usage_message_mc("",$Hf);}
  print "unprocessed args: @ARGV\n" if ($debug_val >=35);
  my %options = ();
  if (! getopts('a:b:cd:ef:i:kl:m:n:opq:r:s:tu:xz-:', \%options)) {
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
     print STDOUT "  No image data to be copied from archive. Data should be available. (-e)\n" if ($debug_val>=10);
  } else {
     $data_pull = 1;
     print STDOUT "  Copying image data from archive.\n" if ($debug_val>=10);
  }
  $arg_hash{data_pull}=$data_pull;

  my $coil_bias;
  if (defined $options{c}) {  # -c
     $coil_bias = 1;
     push @singleopts,'c';
     print STDOUT "  Coil bias will be applied prior to registration. (-c)\n";
  } else {
     $coil_bias = 0;
#     print STDERR "  Coil bias not selected.\n";
  }
  $arg_hash{coil_bias}=$coil_bias;

  my $port_atlas_mask;
  if (defined $options{p}) {  # -p
     $port_atlas_mask = 1;
     push @singleopts,'p';
     print STDOUT "  Porting atlas mask via registration to generated.(-p)\n";
  } else {
     $port_atlas_mask = 0;
#     print STDERR "  Port mask disabled\n";
  }
  $arg_hash{port_atlas_mask}=$port_atlas_mask;

  my $use_existing_mask;
  if (defined $options{k}) {  # -k
     $use_existing_mask = 1;
     push @singleopts,'k';
     print STDOUT "  Using existing mask named runno_channel1_manual_mask.nii. (-k)\n";
  } else {
     $use_existing_mask = 0;
  }
  $arg_hash{use_existing_mask}=$use_existing_mask;

  if (defined $options{t}) { #-t   testmode
      $test_mode = 1;
      push @singleopts,'t';
      print STDOUT "  TESTMODE enabled, will do very fast(incomplete) ANTS calls! (-t)\n" if ($debug_val>=10);
  }
  print "testmode:$test_mode\n" if ($debug_val>=45); 

  
  my $flip_x = 0;
  if (defined $options{x}) {  # -x
     $flip_x = 1;
     push @singleopts,'x';
     print STDOUT "  Rotating input images for x. (-x)\n" if ($debug_val>=10);
  } else {
     $flip_x = 0;
     print STDOUT "  Not rotating input images for x.\n" if ($debug_val>=10);
  }
  $arg_hash{flip_x}=$flip_x;

  my $flip_z ;
  if (defined $options{z}) {  # -z
     $flip_z = 1;
      push @singleopts,'z';
     print STDOUT "  Rotating input images for z. (-z)\n" if ($debug_val>=10);
  } else {
     $flip_z = 0;
     print STDOUT "  Not Rotating input images for z.\n" if ($debug_val>=10);
  }
  $arg_hash{flip_z}=$flip_z;
  

  ##opts with arguments
 ## BJ - Added code for atropos option ["f" for now (cuz we use the FA image)].
  my $atropos_channel;
  if (defined $options{f}) {  # -f
     $allowed_atropos_channels =  allowed_channels($Hf,'allowed_atropos_channels');
     if (! $allowed_atropos_channels) {
	 $allowed_atropos_channels = 'fa,';
     } else {
	 $allowed_atropos_channels = $allowed_atropos_channels.',';
     }
     $atropos_channel = $options{f};
     my $channel_string = $atropos_channel.',';
     if ($allowed_atropos_channels !~ m/($atropos_channel)(,){1}/) {
	 error_out( " The channel \"".$atropos_channel."\" is currently not supported for use with Atropos. Pipeline not initialized. \n");
     }
      $arg_hash{atropos_channel}=$atropos_channel;   
      $cmd_line = "-f $atropos_channel " . $cmd_line;   
   }

  my $channel_order='T1,T2W,T2star';
  if (defined $options{q}) {  # -q 
      $channel_order = $options{q};
      if (defined $options{f}) {                          # BJ -- Need to add Atropos channel to channel queue if not already there, 
	  if ($channel_order !~ m/($atropos_channel)/) {  #       so that the data will be properly processed before it is called.
	     $channel_order=$channel_order.",",$atropos_channel;
	     print STDOUT "  Atropos channel $atropos_channel added to end of channel queue.";
	  }
      } 
      $cmd_line = "-q $channel_order " . $cmd_line;
  } else { 
      print STDOUT "  Using default channel order $channel_order\n" if ($debug_val>=10);
  }
  $arg_hash{channel_order}=$channel_order;

 my $registration_channels=2;
  if (defined $options{m}) {  # m
     $registration_channels = $options{m};
     $cmd_line =  "-m $registration_channels " . $cmd_line ;
     print STDOUT "  Registration channels specified, will use up to ${registration_channels} channels. (-m)\n";
  } else {
     print STDOUT "  Registration channels not specified, using up to 2.\n";
  }
  $arg_hash{registration_channels}=$registration_channels;

 ##opts with arguments
  my $roll_string='0:0';
  if (defined $options{r}) {  # -r 
      $roll_string = $options{r};
      $cmd_line = "-r $roll_string " . $cmd_line;      if( $roll_string !~m/^[0-9]+:[0-9]+$/){
	usage_message_mc("  Using roller requires two parameters separated by : no spaces"); 
      }
  } else { 
      print STDOUT "  No rolliing specified, leaving image in original position $roll_string\n" if ($debug_val>=10);
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
    print STDOUT "  Using default transform direction $transform_direction\n" if ($debug_val>=10);
  }
  $arg_hash{transform_direction}=$transform_direction;



  my $noise_reduction;
  if (defined $options{n}) {  # -n
     $noise_reduction = $options{n};
     $cmd_line = " -n $noise_reduction " . $cmd_line;
     print STDOUT "  Noise reduction using the $noise_reduction algorithm will be applied prior to registration. (-n)\n";
  }
  else {
     $noise_reduction = "--NONE";
#     print STDERR "  Noise reduction not selected.\n";
  }
  $arg_hash{noise_reduction}=$noise_reduction;

  my $bit_mask = "111111111"; # Bit mask now has 9 options instead of 8, in order to call or ignore the Atropos module.
  if (defined $options{b}) {  # -b
     $bit_mask = $options{b};
     if (! defined $options{f}) {      # It can't be assumed that the users who don't need Atropos will be used to accounting for it in their bit mask.
	 if ( length($bit_mask)<9) {   # If bit mask length is 8 or shorter, it is assumed that user is NOT designating a bit for Atropos...
	     $bit_mask=$bit_mask."0";  # ...so a zero is added to the end of the bit mask to ignore all Atropos-related aspects of the pipeline.
	 }
     }
     while( length("$bit_mask")<8){    # Until the bit mask has a length of 9...
	 $bit_mask="0".$bit_mask;      # ...zeros are prepended to it.
     }
     $cmd_line = "-b $bit_mask " . $cmd_line;
     print STDOUT "  go bitmask: $bit_mask (set with -b)\n" if ($debug_val>=10);
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

  }
  if (defined $options{a}) { # -a 
      $atlas_id = $options{a};
      $cmd_line = "-a $atlas_id " . $cmd_line;
  }
  $arg_hash{atlas_images_dir}=$atlas_images_dir;
  $arg_hash{atlas_id}=$atlas_id;


  my $sliceselect;
  if (defined $options{s}) {  # -s
      $sliceselect = $options{s};
      $cmd_line =  "-s $sliceselect " . $cmd_line;
      print STDOUT "  Only slices $sliceselect will be used(-s)\n";
  }
  else {
      $sliceselect = "all";
      print STDOUT "  Will use all slices.\n";
  }
  $arg_hash{sliceselect}=$sliceselect;



## BJ - Added code for custom atropos options ["u" is for "user-defined", I suppose].
  my $atropos_options;
  my $atropos_options_validation;
  if (defined $options{u}) {  # -u
      $atropos_options = $options{u}; # Set to the parameter file path...
#     if (! -e $atropos_options) {    # ...unless it is not a valid file, then check for a string...
#	  $atropos_options_validation = 1;
#	  if ($atropos_options){
#	      error_out("\n  Invalid Atropos parameters entered.  Must be either a valid parameter file or the precise Atropos command line options in double quotes ");}
#	  print STDOUT "  Running Atropos module with default parameters./n";	  
#      }
#      else {
#	  print STDOUT "  Running Atropos module with parameters specified in $atropos./n";
#      }
      #$arg_hash{atropos_channel}=$atropos_channel;   
      #$cmd_line = "-f $atropos " . $cmd_line;   
   }
   #$arg_hash{atropos}=$atropos;

  $arg_hash{threshold_code}=2;
  if (defined $options{'-'}) { # extra options processing
      my $extra_runno_suffix = "--NONE";  
      my @extended_opts=split(',',$options{'-'});

      for my $opt (@extended_opts) {
	  $options{'-'}=$opt;
	  if ($options{'-'} =~ /^suffix=.*/) {  # --suffix
	      ($options{'-'},$extra_runno_suffix)=split('=',$options{'-'});
	      $extra_runno_suffix=~s/(?:^ +)||(?: +$)//g ;
#	      $extra_runno_suffix = $options{'-'};
	      $cmd_line = " --suffix=$extra_runno_suffix " . $cmd_line;
	      print STDOUT "  Adding your suffix to result runno: --suffix=$extra_runno_suffix\n" if ($debug_val>=10);
	      $arg_hash{extra_runno_suffix}=$extra_runno_suffix;
	  } elsif ($options{'-'} =~ /^threshold=.*/) {  # --threshold
	      ($options{'-'},$arg_hash{threshold_code})=split('=',$options{'-'});
	      $cmd_line = " --threshold=$arg_hash{threshold_code} " . $cmd_line;
	      print STDOUT "  using thrshold_code: --threshold=$arg_hash{threshold_code}\n" if ($debug_val>=10);
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
