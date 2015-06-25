#!/usr/local/pipeline-link/perl
# main_seg_pipe_mc.pl
# created 2009/10/27 Sally Gewalt CIVM
#
# Main for segmentation pipeline.  
# This should only set up and check environment, 
# and then call another perl module to do real segmentation specific work.
#
# 2013/07/30 james, updated flip_y code to say flip-x which is what had really been going on all along, rather we rotated on the z dimension, changing both y and x..
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
my $GOODEXIT = 0;
my $BADEXIT  = 1;
my $ERROR_EXIT=$BADEXIT;
use Env qw(PIPELINE_SCRIPT_DIR);
# generic incldues
use Cwd qw(abs_path);
use File::Basename;
use lib dirname(abs_path($0));
use Env qw(RADISH_PERL_LIB);
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quitting\n";
    exit $ERROR_EXIT;
}

use lib split(':',$RADISH_PERL_LIB);
require Headfile;
require pipeline_utilities;
require civm_simple_util;
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
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $Temp_Hf $GOODEXIT $BADEXIT $nchannels);
use civm_simple_util qw(file_exists);
my $debug_val = 35;

$Temp_Hf = new Headfile;
my $pipeline_path=dirname(abs_path($0));
my $pipeline_name='main_seg_pipe_mc.pl';
$Temp_Hf->set_value('calling_program_path',$pipeline_path);
$Temp_Hf->set_value('calling_program_name',$pipeline_name);
$Temp_Hf->set_value('calling_program',$pipeline_path.'/'.$pipeline_name);


###
# SCRIPT AND WORLD GLOBALS
###
my $ANTSAFFINEMETRIC ="mattes"; # "MI"; # could be any of the ants supported metrics, this is stored in our HfResult to be looked up by other functions,this should  be  a good way to go about things, as we can change in the future to use different metrics for different steps by changing the name of this in the headfile, and looking up those different variable names in the pipe.
my $ANTSDIFFSyNMETRIC = "CC"; # could be any of the ants supported metrics, this is stored in our HfResult to be looked up by other functions,this should  be  a good way to go about things, as we can change in the future to use different metrics for different steps by chaning the naem of this in the headfile, and looking up those different variable names in the pipe.
#$nchannels = 2; # number of channels to include in metrics, be nice to use all channels, but thats for the future, will have to edit lines containing this to be $#channel_list instead, to use all possible channels. perhaps we should do some kindof either or, another option flag telling the number of specified channels to use for the registration.
# this has been set up as the -m option, will remain undocumented for now. 
my  $NIFTI_MFUNCTION = 'civm_to_nii';  
# flip functionality put into civm_to_nii
# an mfile function in matlab directory, but no .m here 
# _may version includes flip_z (_feb does not)
# flip version can flip nifti's 
# note: nii conversion function requires big endian input image data at this time
# note: function handles up to 999 images in each set now


# ---- main ------------
# pull inputs using the command_line_mc input parser.
my $err_buffer = ''; #error message buffer, while parsing input its nice to see check multiple error independent error conditions, this way we can show as many as possible to user to fix at a time. 
my $arg_hash_ref = command_line_mc($Temp_Hf);
print "command_line_mc return val: $arg_hash_ref\n" if ($debug_val >=45);
my %arghash=%{$arg_hash_ref};
 foreach my $k (keys %arghash) {
     print "$k: $arghash{$k}\n" if ($debug_val >=35);
 }
my @runno_list     = split(',',$arghash{runnolist});
my @channel_list   = split(',',$arghash{channel_order});
my ($subproject_source, $subproject_result) = split( ',',$arghash{projlist});
my $flip_x = $arghash{flip_x};                     # -y 
my $flip_z = $arghash{flip_z};                     # -z
my $slice_select=$arghash{sliceselect};            # -s #-#
my $noise_reduction = $arghash{noise_reduction};   # -n
my $coil_bias = $arghash{coil_bias};               # -c
my $transform_direction = $arghash{transform_direction};
my $pull_source_images = $arghash{data_pull};      # -e
my $extra_runno_suffix = $arghash{extra_runno_suffix}; # --suffix=something 
my $threshold_code     = $arghash{threshold_code}; # --threshold=number
my $atropos_pf = $arghash{atropos};                # -f /somefile/ or "DEFAULT" or zero--currently WRONG, need to fix
my $atropos_channel = $arghash{atropos_channel};   # 
my $do_bit_mask = $arghash{bit_mask};              # -b 111111111
my $atlas_labels_dir = $arghash{atlas_labels_dir}; # -l /somedir/
   $nchannels = $arghash{registration_channels};   # -m this is subject to change
my $atlas_id = $arghash{atlas_id};                 # -a this is subject to change
#my $user_id = $arghash{user_id};
my $atlas_images_dir = $arghash{atlas_images_dir}; # -i /somedir/
my $port_atlas_mask=$arghash{port_atlas_mask};     # -p 
my $roll_string     = $arghash{roll_string};       # -r rolling with array rx ry
my $use_existing_mask=$arghash{use_existing_mask};     # -k
my $cmd_line = $arghash{cmd_line};




if ( $noise_reduction eq "--NONE" ) {
    $do_bit_mask=($do_bit_mask & "101111111"); # disable the noise do bit if we're not supposed to be noise correcting, this is only part of the enable code, see also the noise_reduction hf key
}# 0100000xor
if ( $coil_bias == 0 ) {
    $do_bit_mask=($do_bit_mask & "110111111"); # disable the coil do bit if we're not supposed to be coil bias correcting, this is only part of the enable code, see also the coil_bias hf key
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
if (! -d $atlas_labels_dir) { error_out ("unable to find canonical labels directory $atlas_labels_dir");  } 
$HfResult->set_value('dir-atlas-labels', $atlas_labels_dir);


if ($atlas_images_dir eq "DEFAULT") { # handle -i and -a options
   $atlas_images_dir = $HfResult->get_value('dir-whs-images-default');
} else {
  if ($atlas_id eq 'DEFAULT') { 
    $atlas_id='whs';
  }
}

$HfResult->set_value('reg-target-atlas-id',$atlas_id);
$HfResult->set_value('dir-atlas-images', $atlas_images_dir);
$HfResult -> set_value('transform_direction',$transform_direction);

if (! -d $atlas_images_dir) { error_out ("unable to find canonical images directory $atlas_images_dir");  } 
log_info("        canonical images dir = $atlas_images_dir"); 

$HfResult->set_value('ANTS-affine-metric',$ANTSAFFINEMETRIC);
$HfResult->set_value('ANTS-diff-SyN-metric',$ANTSDIFFSyNMETRIC);

###
# check channels and runnos and nchannels
###
# runnumbers is the list of runnumber specefied
# channel list is the "queue" of channel identifiers specified with -q
# nchannels is an override to the number of channels to register (-m)
my @tmparray=();
# possible error conditions, 
# size of runno_list < size of channel_list (eg you have specified more channels in -q than the list of runnumbers.)
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
{print("Registering using metrics for the first $nchannels channels.\n") ; sleep(3);}

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
    pull=$pull_source_images, flip_x=$flip_x, flip_z=$flip_z, noise_reduction:$noise_reduction, coil_bias=$coil_bias,
    registration_channels:$nchannels,
    atropos_channel: $atropos_channel,
    suffix=$extra_runno_suffix,
    port_atlas_mask=$port_atlas_mask,
    roll_string=$roll_string,
    use_existing_mask=$use_existing_mask,
    domask=$do_bit_mask
    atlas_labels_dir=$atlas_labels_dir
    atlas_images_dir=$atlas_images_dir
    Base name that will be used to ID this segmentation: $nominal_runno\n") if ( $debug_val >= 5); # print this most of the time, should make verbosity flag.

###
# error check atlas
###
$err_buffer=''; #error message buffer, so we'll see all errors with atlas before quiting. 
my $labelfile ="$atlas_labels_dir/${atlas_id}_labels.nii";

#for my $ch_id (@channel_list) {#fixed to ignore atlas checks on volumes we're not registerting
for ( my $ch_num=0; $ch_num<$nchannels; $ch_num++) {
    my $ch_id=$channel_list[$ch_num];
    my $imagefile ="$atlas_images_dir/${atlas_id}_${ch_id}.nii";
    if ( ! file_exists($imagefile."(.gz)?")) {
	$err_buffer = $err_buffer . "\n\t$imagefile";
    }
}
if (! file_exists($labelfile."(.gz)?")) {
    $err_buffer = $err_buffer . "\n\t$labelfile";
}
# if there was an error locating the atlas image files or labels
error_out ("$PIPELINE_NAME Missing atlas files:$err_buffer") unless ($err_buffer eq '');

$HfResult->set_value('runno_ch_commalist'      , join(',',@channel_list));
$HfResult->set_value('runno_commalist'         , join(',',@runno_list));
$HfResult->set_value('subproject_source'       , $subproject_source);
$HfResult->set_value('subproject_result'       , $subproject_result);
$HfResult->set_value('flip_x'                  , $flip_x);
$HfResult->set_value('flip_z'                  , $flip_z);
$HfResult->set_value('roll_string'             , $roll_string);
$HfResult->set_value('slice-selection'         , $slice_select);
$HfResult->set_value('noise_reduction'         , $noise_reduction);
$HfResult->set_value('coil_bias'               , $coil_bias);
$HfResult->set_value('port_atlas_mask'         , $port_atlas_mask);
$HfResult->set_value('use_existing_mask'       , $use_existing_mask);
$HfResult->set_value('threshold_code'          , $threshold_code);
$HfResult->set_value('registration_channels'   , $nchannels);

if ($atropos_channel) {
    $HfResult->set_value('atropos_channel',$atropos_channel);
    if ($atropos_pf) {
	$HfResult->set_value('atropos_parameter_file', $atropos_pf);
    }
}

#get specid from data headfiles?
$HfResult->set_value('U_specid'  , "NOT_HANDLED_YET");
# --- set runno info in HfResult
print ("Inserting Channel runnos to headfile:\n");

# --- get source images, genericified for arbitrary channels
my $dest_dir = $HfResult->get_value('dir-input'); # for retrieved images
if (! -d $dest_dir) { mkdir $dest_dir; }
if (! -d $dest_dir) { error_out ("no dest dir! $dest_dir"); }

my $i;
for($i=0;$i<=$#runno_list;$i++) {
    print ("\t${channel_list[$i]}\n") if ($debug_val >=5);
    $HfResult->set_value("${channel_list[$i]}-runno", $runno_list[$i]);
}

$HfResult->set_value("nifti_matlab_converter",$NIFTI_MFUNCTION); 
# foreach cahnnel run function in retrieve_archived_data.pm, will retrieve images and set some headfile keys
# ${ch_id}[-_]path                 
# ${ch_id}[-_]-image-padded-digits 
# ${ch_id}[-_]-image-basename      
# ${ch_id}[-_]-image-suffix         

###
# Set the archive research keys 
##
# archivedestination_project_directory_name=13.mcnamara.02
# archivedestination_unique_item_name=tensorS64487_m0
# archivesource_computer=crete
# archivesource_directory=/cretespace
# archivesource_headfile_creator=Tensor Pipeline 2011/03/02
# archivesource_item=tensorS64487_m0-DTI-results 
# archivesource_item_form=directory-set
my $OUTPUT_FORMAT      = 'txt';
#$HfResult->set_value('U_specid'              , $HfResult->get_value('specid_'.$channel_list[0]));
$HfResult->set_value('U_db_insert_type'      , "research");
#   recommended U_params for archive
$HfResult->set_value('U_parent_runno'        , $runno_list[0]);
$HfResult->set_value('U_root_runno'          , $runno_list[0]);
$HfResult->set_value('U_code'                , $subproject_result);
#$HfResult->set_value('U_civmid'              , $user_id);
$HfResult->set_value('U_stored_file_format'  , $OUTPUT_FORMAT);
$HfResult->set_value('parent_subproject'     , $subproject_source);
$HfResult->set_value('U_rd_modality'         , "research Segmentaion");
#   required for archive operation
$HfResult->set_value('archivesource_headfile_creator' , "$PIPELINE_NAME $PIPELINE_VERSION");
# archive the result-dir content with the dir name like tensorRUNNO...
my $result_dir =  $HfResult->get_value('dir-result');
my $path = defile($result_dir);
my $last_dir = depath($result_dir);
$HfResult->set_value('archivesource_item_form' , "directory-set");
$HfResult->set_value('archivesource_item'      , $last_dir);
$HfResult->set_value('archivesource_directory' , $path );
$HfResult->set_value('archivedestination_unique_item_name'      , $nominal_runno."Labels");
$HfResult->set_value('archivedestination_project_directory_name', $subproject_result);

for my $ch_id (@channel_list) {
    locate_data_util($pull_source_images, "${ch_id}" , $HfResult);
}
# $flip_x, $flip_z,
label_brain_pipe($do_bit_mask, $HfResult);  # --- pipeline work is here
###
# set last archive research keys.
###
$HfResult->set_value('U_date'                , $HfResult->now_date_db()); #  "10-05-14 09:30:20"
$HfResult->set_value('archivesource_computer'         , $HfResult->get_value('engine-computer-name') );
#print $HfResult->get_value('engine_computer_name')."\n";

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
