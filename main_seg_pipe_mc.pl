#!/usr/local/pipeline-link/perl
# main_seg_pipe_mc.pl
# created 2009/10/27 Sally Gewalt CIVM
#
# Main for segmentation pipeline.  
# This should only set up and check environment, 
# and then call another perl module to do real segmentation specific work.
#
# 2012/04/03 james, updated lots of things, specifically changed hard coded references to whs to atlas, and made channel inputs arbitrary 
# 2011/01/21 slg command line options to change default locations: dir_whs_labels_default, dir_whs_images_default
# 2010/11/02 updates for handling voxel size info from header 
# 2010/03/04 Alex iteration adjustments, ANTS update, more images in -results dir.
# 2009/12/14 slg use "do bits" to toggle steps on and off.
#





#package seg_pipe_mc;

use strict;
use List::Util qw(min);
#require Exporter; 
use Env qw(PIPELINE_SCRIPT_DIR);
use lib "$PIPELINE_SCRIPT_DIR/pipeline_utilities"; # look in here for the requirements
# generic incldues
require Headfile;
require pipeline_utilities;
require retrieve_archived_data;
# specific includes, these are pms specific to seg_pipe_mc and reside in its directory, 
# comand+line_mc and seg_pipe, might make sense to build a "analysis_pipe" class out of, 
# that will be future work. 
require command_line_mc;
require seg_pipe;
require label_brain_pipe;

# fancy begin block and use vars to define a world global variable, available to any module used at the same time as this one
BEGIN {
    use Exporter; 
    @label_brain_pipe::ISA = qw(Exporter);
#    @label_brain_pipe::Export = qw();
    @label_brain_pipe::EXPORT_OK = qw($nchannels);
}
# most of these variables are defined in seg_pipe.pm as they are static, nchannels is defined here
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT $nchannels);
my $debug_val = 35;


###
# SCRIPT AND WORLD GLOBALS
###
my $ANTSAFFINEMETRIC = "MI"; # could be any of the ants supported metrics, this is stored in our HfResult to be looked up by other functions,this should  be  a good way to go about things, as we can change in the future to use different metrics for different steps by chaning the naem of this in the headfile, and looking up those different variable names in the pipe.
my $ANTSDIFFSyNMETRIC = "CC"; # could be any of the ants supported metrics, this is stored in our HfResult to be looked up by other functions,this should  be  a good way to go about things, as we can change in the future to use different metrics for different steps by chaning the naem of this in the headfile, and looking up those different variable names in the pipe.
#$nchannels = 2; # number of channels to include in metrics, be nice to use all channels, but thats for the future, will have to edit lines containing this to be $#channel_list instead, to use all possible channels. perhaps we should do some kindof either or, another option flag telling the number of specified channels to use for the registration.
# this has been set up as the -m option, will remain undocumented for now. 

# ---- main ------------
# pull inputs using the command_line_mc input parser.
my $err_buffer = ''; #error message buffer, while parsing input its nice to see check multiple error independent error conditions, this way we can show as many as possible to user to fix at a time. 
my $arg_hash_ref = command_line_mc(@ARGV);
print "command_line_mc return val: $arg_hash_ref\n" if ($debug_val >=45);
my %arghash=%{$arg_hash_ref};
 foreach my $k (keys %arghash) {
     print "$k: $arghash{$k}\n" if ($debug_val >=35);
 }
my @runno_list                                                 = split(',',$arghash{runnolist});
my @channel_list                                               = split(',',$arghash{channel_order});
my ($subproject_source, $subproject_result) = split( ',',$arghash{projlist});
my $flip_y = $arghash{flip_y};                     # -y 
my $flip_z = $arghash{flip_z};                     # -z
my $noise_reduction = $arghash{noise_reduction};   # -n
my $coil_bias = $arghash{coil_bias};               # -c
my $transform_direction = $arghash{transform_direction};
my $pull_source_images = $arghash{data_pull};      # -e
my $extra_runno_suffix = $arghash{extra_runno_suffix}; # -s 
my $do_bit_mask = $arghash{bit_mask};              # -b
my $atlas_labels_dir = $arghash{atlas_labels_dir}; # -l
$nchannels = $arghash{registration_channels};      # -m this is subject to change
my $atlas_id = $arghash{atlas_id};                 # -a this is subject to change
my $atlas_images_dir = $arghash{atlas_images_dir}; # -i
my $port_atlas_mask=$arghash{port_atlas_mask};     # -p 
my $cmd_line = $arghash{cmd_line};




if ( $noise_reduction eq "--NONE" ) {
    $do_bit_mask=($do_bit_mask & "10111111"); # disable the noise do bit if we're not supposed to be noise correcting, this is only part of the enable code, see also the noise_reduction hf key
}# 0100000xor
if ( $coil_bias == 0 ) {
    $do_bit_mask=($do_bit_mask & "11011111"); # disable the coil do bit if we're not supposed to be coil bias correcting, this is only part of the enable code, see also the coil_bias hf key
}# 0100000xor

###
# process the input params abit, print directly after
###
my $nominal_runno = "xxx"; 
if ($extra_runno_suffix eq "--NONE") {
#  $nominal_runno = $runno_channel1_set;  # the "nominal runno" is used to id this segmentation
  $nominal_runno = $runno_list[0];  # the "nominal runno" is used to id this segmentation
} else {
  print "Extra runno suffix info provided = $extra_runno_suffix\n";
  $nominal_runno = $runno_list[0] . $extra_runno_suffix; 
}
set_environment($nominal_runno); # opens headfile, log file, loads the setting variables from dependency files into the headfile. 

$HfResult->set_value('program_arguments',$cmd_line);
if ($atlas_labels_dir eq "DEFAULT") { # handle -l option
    $atlas_labels_dir = $HfResult->get_value('dir-whs-labels-default');

}
log_info("  Using canonical labels dir = $atlas_labels_dir"); 
if (! -e $atlas_labels_dir) { error_out ("unable to find canonical labels directory $atlas_labels_dir");  } 
$HfResult->set_value('dir-atlas-labels', $atlas_labels_dir);


if ($atlas_images_dir eq "DEFAULT") { # handle -i and -a options
  $atlas_id = 'whs';
  $atlas_images_dir = $HfResult->get_value('dir-whs-images-default');
} else {
  if ($atlas_id eq 'DEFAULT') { 
    $atlas_id='whs';
  }
}

$HfResult->set_value('reg-target-atlas-id',$atlas_id);
$HfResult->set_value('dir-atlas-images', $atlas_images_dir);
$HfResult -> set_value('transform_direction',$transform_direction);

if (! -e $atlas_images_dir) { error_out ("unable to find canonical images directory $atlas_images_dir");  } 
log_info("        canonical images dir = $atlas_images_dir"); 

$HfResult->set_value('ANTS-affine-metric',$ANTSAFFINEMETRIC);
$HfResult->set_value('ANTS-diff-SyN-metric',$ANTSDIFFSyNMETRIC);

###
# check channels and runnos and nchannels
###
my @tmparray=();
# possible error conditions, 
# size of runno_list < size of channel_list 
if ( $#runno_list<$#channel_list){
    print("WARNING: More channels specified than provided, guessing correct number\n"); # if ($debug_val >=35);
    for (my $run=0;$run<=$#runno_list;$run++) {
	push @tmparray, $channel_list[$run];
    }
    @channel_list=@tmparray;
}
#size of runno_list < nchannels
if ($#runno_list<$nchannels-1 ) { # this maybe should be<= not <
    print("WARNING: More channels desired for regiistration than provided, guessing correct number\n"); # if ($debug_val >=35);
    $nchannels=min($#channel_list,$#runno_list)+1; 
    
    for (my $run=0;$run<=$#runno_list;$run++) {
	push @tmparray, $channel_list[$run];
    }
    @channel_list=@tmparray;
} 
if ($#channel_list<$nchannels-1) { # $# is max_index of 0 indexed array, so we in fact need to look for 1 less than the real number of channels
        log_info("Only found $#channel_list channels. MUST SPECIFY TWO OR THREE CHANNELS.(The third is mostly along for the ride.) Less than 2 channels not currently tested, all registrations based on two channels, ");

	print ("WARNING: changing number of channels to ($#runno_list+1)\n");
	$nchannels=$#channel_list+1;
} 
if ($debug_val>=35)
{print("Registering using metrics for the frist $nchannels channels.\n") ; sleep(3);}

###
# find the ANTS metric weights in opts file
###
#this section in major flux, swithching between an absolute channel identity and a relative one, 
# we're unsure how to arbitrarily handle the metric type, since registration weighting will 
# depend on which metrics we're using, we're changing the metric options file from T1,T2W,T2star, etc to CH1, CH2, etc. 
my $HfAntsmetrics = get_ants_metric_opts();
# my $transformtype="affine";
# for my $ch_id (@channel_list) { 
#     my $opt=$HfAntsmetrics->get_value("${transformtype}-${ANTSAFFINEMETRIC}-${ch_id}");
#     if ($opt eq 'UNDEFINED_VALUE' || $opt eq 'NO_KEY') { error_out("could not get metric ${transformtype}-${ANTSAFFINEMETRIC}-${ch_id} from ants $transformtype metric options");}
#     $HfResult->set_value ("${transformtype}-${ANTSAFFINEMETRIC}-${ch_id}-weighting",$opt);
# } 
# $transformtype="diff-SyN";
# for my $ch_id (@channel_list) { 
#     my $opt=$HfAntsmetrics->get_value("${transformtype}-${ANTSDIFFSyNMETRIC}-${ch_id}");
#     if ($opt eq 'UNDEFINED_VALUE' || $opt eq 'NO_KEY') { error_out("could not get metric ${transformtype}-${ANTSDIFFSyNMETRIC}-${ch_id} from ants $transformtype metric options");}
#     $HfResult->set_value ("${transformtype}-${ANTSDIFFSyNMETRIC}-${ch_id}-weighting",$opt);
# }
my $transformtype = "affine";
$err_buffer = ''; #clear buffer to for looking up the metric options in the metric opts file
print("ANTS metric weighting options\n");
#for my $ch_id (@channel_list) { 
for(my $num=0;$num<=$nchannels-1;$num++) { 
    my $ch_id = "CH" . ($num+1) ;
    my $opt = $HfAntsmetrics->get_value("${transformtype}-${ANTSAFFINEMETRIC}-${ch_id}");
    if ($opt eq 'UNDEFINED_VALUE' || $opt eq 'NO_KEY') {
	$err_buffer = $err_buffer . "\n\tcould not get metric ${transformtype}-${ANTSAFFINEMETRIC}-${ch_id} from ants $transformtype metric options" ;
    } else { 
	$ch_id = $channel_list[$num];# despite getting the ch1 id from the option file, we're still gonna store it under the t1, etc option in out headfile. 
	$HfResult->set_value ("${transformtype}-${ANTSAFFINEMETRIC}-${ch_id}-weighting",$opt);
	log_info("\tchannel" . ($num+1) ."=${transformtype}-${ANTSAFFINEMETRIC}-${ch_id}-weighting <- $opt");
    }
} 
$transformtype = "diff-SyN";
for(my $num=0;$num<=$nchannels-1;$num++) { 
    my $ch_id = "CH" . ($num+1) ;
    my $opt = $HfAntsmetrics->get_value("${transformtype}-${ANTSDIFFSyNMETRIC}-${ch_id}");
    if ($opt eq 'UNDEFINED_VALUE' || $opt eq 'NO_KEY') {
	$err_buffer = $err_buffer . "\n\tcould not get metric ${transformtype}-${ANTSDIFFSyNMETRIC}-${ch_id} from ants $transformtype metric options";
    } else {
	$ch_id = $channel_list[$num];# despite getting the ch1 id from the option file, we're still gonna store it under the t1, etc option in out headfile. 
	$HfResult->set_value ("${transformtype}-${ANTSDIFFSyNMETRIC}-${ch_id}-weighting",$opt);
	log_info("\tchannel" . ($num+1) ."=${transformtype}-${ANTSDIFFSyNMETRIC}-${ch_id}-weighting <-$opt");
    }
}
# if we got an error finding the metrics print them now
error_out($err_buffer) unless ($err_buffer eq ''); 

print 
("Command line info provided to main:
    raw opts:  $cmd_line
    ".join(',',@channel_list).",
    ".join(',',@runno_list).",
    subproj source: $subproject_source, 
    subproj result: $subproject_result, 
    pull=$pull_source_images, flip_y=$flip_y, flip_z=$flip_z, noise_reduction:$noise_reduction, coil_bias=$coil_bias,
    registration_channels:$nchannels,
    suffix=$extra_runno_suffix 
    port_atlas_mask=$port_atlas_mask,
    domask=$do_bit_mask
    atlas_labels_dir=$atlas_labels_dir
    atlas_images_dir=$atlas_images_dir
    Base name that will be used to ID this segmentation: $nominal_runno\n") if ( $debug_val >= 5); # print this most of the time, should make verbosity flag.

###
# error check atlas
###
$err_buffer=''; #error message buffer, so we'll see all errors with atlas before quiting. 
my $labelfile ="$atlas_labels_dir/${atlas_id}_labels.nii";
for my $ch_id (@channel_list) {
    my $imagefile ="$atlas_images_dir/${atlas_id}_${ch_id}.nii";
    if (!-e $imagefile) {
	$err_buffer = $err_buffer . "\n\t$imagefile";
    }
}
if (!-e $labelfile) {
    $err_buffer = $err_buffer . "\n\t$labelfile";
}
# if there was an error locating the atlas image files or labels
error_out ("$PIPELINE_NAME Missing atlas files:$err_buffer") unless ($err_buffer eq '');

$HfResult->set_value('runno_ch_commalist'      , join(',',@channel_list));
$HfResult->set_value('runno_commalist'         , join(',',@runno_list));
$HfResult->set_value('subproject_source'       , $subproject_source);
$HfResult->set_value('subproject_result'       , $subproject_result);
$HfResult->set_value('flip_y'                  , $flip_y);
$HfResult->set_value('flip_z'                  , $flip_z);
$HfResult->set_value('noise_reduction'         , $noise_reduction);
$HfResult->set_value('coil_bias'               , $coil_bias);
$HfResult->set_value('port_atlas_mask'         , $port_atlas_mask);

#get specid from data headfiles?
$HfResult->set_value('specid'  , "NOT_HANDLED_YET");
# --- set runno info in HfResult
print ("Inserting Channel runnos to headfile:\n");

# --- get source images, genericified for arbitrary channels
my $dest_dir = $HfResult->get_value('dir-input'); # for retrieved images
if (! -e $dest_dir) { mkdir $dest_dir; }
if (! -e $dest_dir) { error_out ("no dest dir! $dest_dir"); }

my $i;
for($i=0;$i<=$#runno_list;$i++) {
    print ("\t${channel_list[$i]}\n") if ($debug_val >=5);
    $HfResult->set_value("${channel_list[$i]}-runno", $runno_list[$i]);
}
for my $ch_id (@channel_list) {
    #print("retrieving archive data for channel ${channel_list[$i]}\n");
    #locate_data($pull_source_images, "${channel_list[$i]}" , $HfResult);
#    print("retrieving archive data for channel ${ch_id}\n");
    locate_data_util($pull_source_images, "${ch_id}" , $HfResult);
    #locate_data_util($pull_source_images, "${ch_id}" ,$runno, $HfResult);
}

# $flip_y, $flip_z,
label_brain_pipe($do_bit_mask, $HfResult);  # --- pipeline work is here

# --- done
my $dest    = $HfResult->get_value('dir-result');
my $hf_path = $HfResult->get_value('headfile-dest-path');

# prepare (via a headfile?) for archive of results

log_info  ("Pipeline successful");
close_log ($HfResult); # also writes log to headfile;

$HfResult->write_headfile($hf_path);

print STDERR "results in $dest\n";
exit $GOODEXIT;

#--------subroutines-------
