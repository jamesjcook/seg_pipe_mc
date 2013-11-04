#!/usr/local/pipeline-link/perl
# create_labels.pm 
 
# based on label_brain_0.sh by abb
# 2012/03/28 james cook, modified to chang whs to atlas, since we can use any 
#            atlas, we shouldnt be calling it whs now should we....
# 2012/03/27 james cook, began modifiication to work for arbitrary mc pipe
# 2011/1/20  skull ref maskfound in selected current canonical labels directory.
# 2010/3/02  slg warpImageMultitransform changed with new ANTS version -  regarding gz??
#                Add Byte conversion ants command to warp_label_image routine.
# 2009/12/09 slg diff syn iteration changes from Alex, orig still working after 3 days
# 2009/12/09 slg iteration changes from Alex
# created 2009/10/28 Sally Gewalt CIVM
# 5 November 2012 use syn 0.75; smoothing [3,1]
# 6 November 2012 use syn 1; smoothing [3,1]

my $VERSION = "2012/04/09";
my $NAME = "Alex Badea brain label creation Method";
my $DESC = "matlab and ants with ref skull mask (v2)";
my $PM = "create_labels.pm";
my $ggo = 1;
my $PM_stages=4;

use strict;
use label_brain_pipe;
use vars qw($test_mode $nchannels);
#nchannels is global number of channels to include in metrics, be nice to use all channels, but thats for the future. 

# both create tranforms subs use these:
my $gcurrent_T2W_path;
my $gcurrent_T1_path;
my $gwhs_T2W_path;
my $gwhs_T1_path;

my $DEBUG_GO = 1;
my $debug_val = 5;
my $SYNSETTING=3; #0.75; #%was 0.5
#my $METRIC = "MI"; # could be any of the ants supported metrics, defined in main as a global, so bad to do that. should really chage that....



# ------------------
sub create_labels {
# ------------------
    my ($go, $Hf) = @_;
    $ggo = $go; 
    my $atlas_id  = $Hf->get_value('reg-target-atlas-id');

    log_info ("$PM name: $NAME; go=$go");
    log_info ("$PM desc: $DESC");
    log_info ("$PM version: $VERSION");

    my $affine_xform  = create_multi_channel_affine_transform ($Hf);

    my ($ants_transform_prefix) = create_multi_channel_diff_syn_transform ($affine_xform, $SYNSETTING , $Hf); 
    #syn_setting defined as 0.5, we could save this to hf perhaps, or more fun, specify it elsewhere and store in headfile.

#  my $label_path      = warp_canonical_labels($ants_transform_prefix, $Hf); # obsolete funciton does same thing as warp_label_image, and warp_label_image has been updated alot since this was in main use.

    #####my $warp_label_path = warp_label_image($ds_affine_xform_base, $ds_warp_xform_base, $Hf);
    my $warp_label_path = warp_label_image($Hf);
    #warp_canonical_image($Hf); # 28 June 2012
    
#  log_info ("Pipeline created result 1: $label_path\n"); # ouput of obsolete function, do not use. 
    log_info ("Pipeline created result 2: $warp_label_path\n");

}

# ------------------
sub create_multi_channel_affine_transform {
# ------------------
#  my ($current_channel2_path_id, $current_channel1_path_id, $Hf) = @_;
# take the two hfkeys to transform to read a path from.
#   this is where we finally check for files existing, i kinda think 
# it'd be good to pull that check out much earlier.
#   i think the metrics should probably be in definition 
# files rather than in the script here. 
# i should work on that. 
# this would change the funtion flow from if metric a, hardcode value b to load metrics, if metric a, value read b .

    my ($Hf) = @_;
    print("\n\n\t$PM stage 1/$PM_stages \"create_multi_channel_affine_transform\" \n") if ($debug_val >= 35) ;
    my $atlas_id         = $Hf->get_value('reg-target-atlas-id');
    my $atlas_images_dir = $Hf->get_value('dir-atlas-images');
    my $ants_app_dir     = $Hf->get_value('engine-app-ants-dir');
    my $work_dir         = $Hf->get_value('dir-work');
    my $metric           = $Hf->get_value('ANTS-affine-metric');
    my @channel_array = split(',',$Hf->get_value('runno_ch_commalist'));
    my $channel1 = ${channel_array[0]};
    my $result_transform_path_base = "$work_dir/${channel1}_label_transform_";
                           # $result_transform_path_base = "$work_dir/${channel1}_label_DIFF_SYN_transform_";# alex 12 october 12
    my $transform_direction=$Hf->get_value('transform_direction');

# build metrics, only using first two channels for now, that is set in the main_seg_pipe_mc script with nchannels variable, 
# if you only specify one channel it will only use one.


    my $metrics='';

    for(my $chindex=0;$chindex<$nchannels;$chindex++) {
	my $ch_id=$channel_array[$chindex];
	print("\tadding metric for ch_id:$ch_id\n");
	my $channel_option = $Hf->get_value("affine-${metric}-${ch_id}-weighting");
	if ( $channel_option eq 'NO_KEY' ) { error_out ("could not find metric affine-${metric}-${ch_id}-weighting "); }
	my $channel_path      = $Hf->get_value("${ch_id}-reg2-${atlas_id}-path");
	my $atlas_image_path  = "${atlas_images_dir}/${atlas_id}_${ch_id}.nii"; # $Hf->get_value();
	if ( ! -e $channel_path ) { # crap out on missing file
	    error_out ("$PM create_multi_channel_affine_transform: $channel_path does not exist<${ch_id}-reg2-${atlas_id}-path>"); 
	} else {
            if ($transform_direction eq 'i')
	      {
		$metrics = $metrics . " -m ${metric}[ ${atlas_image_path},${channel_path},${channel_option}]"; 
	      }
           elsif ($transform_direction eq 'f')
	     {
	       $metrics = $metrics . " -m ${metric}[ ${channel_path},${atlas_image_path},${channel_option}]"; 
	     }
	}
    }
    if ($debug_val>=35) {  
	print("\n\n\n"); 
	sleep(15);
    }
# ########
# #for mutual information metric use THIS IS CONTROLed ELSEWHRE NOW< SET THE ANTSAFFINEMETRIC VALUE at the start of main_seg_pipe_mc.pl
#   my $metric0 = "$gwhs_T1_path,$gcurrent_T1_path,0.7,32";
#   my $metric1 = "$gwhs_T2W_path,$gcurrent_T2W_path,0.3,32";
# #####
# #for PR metric use
#   #my $metric0 = "$gwhs_T2W_path,$gcurrent_T2W_path,0.8,2";
#   #my $metric1 = "$gwhs_T1_path,$gcurrent_T1_path,1,2:";
# ######
    my $affine_iter="3000x3000x3000x100";
    $affine_iter="3000x3000x0x0";
    if ( defined($test_mode)) {
	if( $test_mode == 1 ) {
	    $affine_iter="1x0x0x0";

	}}
#old ants
    my $other_options = "-i 0 --number-of-affine-iterations $affine_iter --MI-option 32x32000 --use-Histogram-Matching --affine-gradient-descent-option 0.05x0.5x0.0001x0.0001"; # can use 0.2x0.5x0.0001x0.0001

#old ants
my $cmd = "$ants_app_dir/ants 3 $metrics -o $result_transform_path_base $other_options";

#new ants
  $cmd = "$ants_app_dir/antsRegistration -d 3 $metrics -t translation[0.25] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 $metrics -t rigid[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 $metrics -t affine[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 -u 1 -z 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4"; 

#let the learning rate be adjustable -l 0 or default
 $cmd = "$ants_app_dir/antsRegistration -d 3 $metrics -t translation[0.25] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 $metrics -t rigid[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 $metrics -t affine[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -u 1 -z 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4"; #this one work pretty well but takes a long time

#trying more smoothing here to speed convergence risk to loose small but strong features
$cmd = "$ants_app_dir/antsRegistration -d 3 $metrics -t rigid[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x1vox -f 6x4x2x1 $metrics -t affine[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0vox -f 6x4x1x1 -u 1 -z 1 -l 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4"; 




#go paralell

    if ($DEBUG_GO) { 
	if (! execute($ggo, "create affine transform for labels", $cmd) ) {
	    error_out("$PM create_affine_transform: could not make transform: $cmd\n");
	}
    } 
    
    my $transform_path = "$result_transform_path_base\Affine.txt";
    $transform_path = "$result_transform_path_base" . "0GenericAffine.mat";
    print "$transform_path\n";


    # suffix mentioned on: http://picsl.upenn.edu/ANTS/ioants.php, and confirmed by what appears!
    # note: don't have any dots . in the middle of your base path, just one at the end: .nii
    
    if (!-e $transform_path && $ggo) {
	error_out("$PM create_affine_transform: did not find result xform: $transform_path");
    }
    print "** $PM create_multi_channel_affine_transform created $transform_path\n";
    return($transform_path);
}

# ------------------
sub create_multi_channel_diff_syn_transform {
# ------------------
    my ($affine_xform, $syn_setting, $Hf) = @_;

    print("\n\n\t$PM stage 2/$PM_stages \"create_multi_channel_diff_syn_transform\" \n\n\n") if ($debug_val >= 35) ;

    my $atlas_id         = $Hf->get_value('reg-target-atlas-id');
    my $atlas_images_dir = $Hf->get_value('dir-atlas-images');
    my $ants_app_dir     = $Hf->get_value('engine-app-ants-dir');
    my $work_dir         = $Hf->get_value('dir-work');
    my $metric           = $Hf->get_value('ANTS-diff-SyN-metric');
    my @channel_array = split(',',$Hf->get_value('runno_ch_commalist'));
    my $channel1 = ${channel_array[0]};
    my $result_transform_path_base = "$work_dir/${channel1}_label_DIFF_SYN_transform_";
    my $transform_direction=$Hf->get_value('transform_direction');
    my $ref_skull_mask='';
    my $canon_image_dir    = $Hf->get_value('dir-atlas-images');
    my $norm_mask_path = $Hf->get_value('skull-norm-mask-path');  # save mask to aid labelling


    #/////// define options for transform ////////// 
# build metrics, only using first two channels for now, i want to change that later. 
    my $metrics='';
    
    my $affine_iter="3000x3000x3000x3000";
    if ( defined($test_mode)) {
	if( $test_mode == 1 ) {
	    $affine_iter="1x0x0x0";
	}
    }
    my $other_options ="";
    $other_options = "--number-of-affine-iterations $affine_iter --MI-option 32x32000 --use-Histogram-Matching";#was 32x16000
   
    ###my $skull_mask   = $Hf->get_value('skull_norm_mask_path');  #### but we don't want to use this current mask for -x
  


    $ref_skull_mask   = "$canon_image_dir/${atlas_id}_mask.nii"; # a canonical reference mask

    if (! -e $ref_skull_mask) {
	error_out ("$PM create_diff_syn_transfrom: Reference skull mask $ref_skull_mask does not exist for -x option") ;
    }

    my $my_options ="";
#long run
    my $diffsyn_iter= "3000x3000x3000x3000"; 
#short run
 $diffsyn_iter="3000x3000x3000x3000" ; # matt change back to "3000x3000x3000";
 $diffsyn_iter="3000x3000x3000";

    if ( defined($test_mode)) {
	if( $test_mode == 1 ) {
	    $diffsyn_iter="1x0x0x0";
            $diffsyn_iter="1x0x0";
	}
    }
  
#go paralell alx
#-f 8x4x4 should become at least -f 8x4x2 but really -f 4x2x1 ->need to time this alex

for(my $chindex=0;$chindex<$nchannels;$chindex++) {
	my $ch_id=$channel_array[$chindex];
	my $channel_option = $Hf->get_value("diff-SyN-${metric}-${ch_id}-weighting");
	if ( $channel_option eq 'NO_KEY' ) { error_out ("could not find metric diff-SyN-${metric}-${ch_id}-weighting "); }
	my $channel_path      = $Hf->get_value("${ch_id}-reg2-${atlas_id}-path");
	my $atlas_image_path  = "${atlas_images_dir}/${atlas_id}_${ch_id}.nii"; # $Hf->get_value();
	if ( ! -e $channel_path ) { # crap out on missing file
	    error_out ("$PM create_multi_channel_affine_transform: $channel_path does not exist<${ch_id}-reg2-${atlas_id}-path>");
	} else {
	    if ($transform_direction eq 'i')
	      {
		
		$metrics = $metrics . " -m ${metric}[${atlas_image_path},${channel_path},${channel_option}]"; 

                $ref_skull_mask   = "$canon_image_dir/${atlas_id}_mask.nii"; # a canonical reference mask
		#$my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x2x1vox -f 8x4x2 -t SyN[$syn_setting,1,0.5] -x [ $ref_skull_mask, $norm_mask_path] -r $affine_xform -a 0 -u 1"; 
		#$my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x2x1vox -f 8x4x4 -t SyN[$syn_setting,3,1] -x [ $ref_skull_mask, $norm_mask_path] -r $affine_xform -a 0 -u 1"; 
	        #$my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x2x1vox -f 8x4x4 -t SyN[$syn_setting,3,0] -x [ $ref_skull_mask, $norm_mask_path] -r $affine_xform -a 0 -u 1 -z 1"; 
                $my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x2x1vox -f 8x4x4 -t SyN[$syn_setting,3,0] -x [ $ref_skull_mask, $norm_mask_path] -r $affine_xform -a 0 -u 1 -z 1"; 
                $my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x3x2vox -f 8x4x4 -t SyN[$syn_setting,3,0] -x [ $ref_skull_mask, $norm_mask_path] -r $affine_xform -a 0 -u 1 -z 1"; 
                $my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x2x1vox -f 4x2x1 -t SyN[$syn_setting,3,0] -x [ $ref_skull_mask, $norm_mask_path] -r $affine_xform -a 0 -l 1 -u 1 -z 1"; 

	      }
           elsif ($transform_direction eq 'f')
	     {
	       $metrics = $metrics . " -m ${metric}[${channel_path},${atlas_image_path},${channel_option}]"; 
               $ref_skull_mask   = $norm_mask_path;
	       $my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x2x1vox -f 8x4x2 -t SyN[$syn_setting,1,0.5] -x [ $norm_mask_path,$ref_skull_mask] -r $affine_xform -a 0 -u 1"; 
	       $my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x2x1vox -f 8x4x4 -t SyN[$syn_setting,3,1] -x [ $norm_mask_path,$ref_skull_mask] -r $affine_xform -a 0 -u 1"; 
               $my_options = "-c [ $diffsyn_iter,1e-8,20] -s 4x2x1vox -f 4x2x1 -t SyN[$syn_setting,3,0] -x [ $norm_mask_path,$ref_skull_mask] -r $affine_xform -a 0 -l 1 -u 1 -z 1"; 
	     }
	}
    }
#long run
#will need to flip the order of the masks in -x for forwd and inverse



#short run
# $my_options = "-c $diffsyn_iter -s 0x0x0x0 -f 8x4x2x1 -t SyN[$syn_setting,1,0.5] -x $ref_skull_mask -r $affine_xform -a 0"; 
  
    #/////// define ants transform command including all options ///////
   
#go paralell alx
    my $cmd = "$ants_app_dir/antsRegistration -d 3 $metrics -o $result_transform_path_base $my_options";


    if ($DEBUG_GO) { 
	if (! execute($ggo, "create affine diff syn transform for labels 8/2013\n\n\n", $cmd) ) {
	    error_out("$PM create_multi_channel_diff_syn_transform: could not make transform: $cmd\n");
	}
    } 
    #    my $affine_xform_base           = $result_transform_path_base . "Affine"; #bogus with new version of ants
    # Should find a better way to find these than to use the _alt method, should do a search on wild card to get the right filename, this will work for now. 
    my $diff_syn_xform_base             = $result_transform_path_base . "Warp";
    my $diff_syn_xform_base_alt         = $result_transform_path_base . "1Warp";
    my $diff_syn_inverse_xform_base     = $result_transform_path_base . "InverseWarp";
    my $diff_syn_inverse_xform_base_alt = $result_transform_path_base . "1InverseWarp";
    my $ants_transform_prefix = $result_transform_path_base;

    $Hf->set_value('diff_affine', $affine_xform);
    if ( -e $diff_syn_xform_base.".nii.gz" && $ggo ) { 
      $Hf->set_value('diff_warp', $diff_syn_xform_base);
      $Hf->set_value('diff_inv_warp', $diff_syn_inverse_xform_base);
      print "** $PM create_multi_channel_diff_syn_transform created $diff_syn_xform_base\.nii.gz, etc\n";
    } else { 
      if ( ! -e $diff_syn_xform_base_alt.".nii.gz" && $ggo ) {      
	error_out("$PM create_multi_channel_diff_syn_transform: did not find result xform: $diff_syn_xform_base_alt\.nii.gz or $diff_syn_xform_base\.nii.gz");
      } #lazy fall through without else to keep code smaller. 
      $Hf->set_value('diff_warp', $diff_syn_xform_base_alt);
      $Hf->set_value('diff_inv_warp', $diff_syn_inverse_xform_base_alt);
      print "** $PM create_multi_channel_diff_syn_transform created $diff_syn_xform_base_alt\.nii.gz, etc\n";
    }
    #go paralell alx
    return($ants_transform_prefix);
}

# ------------------
sub warp_label_image {
# ------------------
# applys warp transform in the domain of the atlas used to labels
# this function is nearly itdentical to warp_canonical_label
# this should warp from atlas labels to the atlas registered input images. 
# my ($affine_xform, $warp_xform, $Hf) = @_;
    my ($Hf) = @_;
    print("\n\n\t$PM stage 3/$PM_stages \"warp_label_image\" \n\n\n") if ($debug_val >= 35) ;

    my $label_dir        = $Hf->get_value('dir-atlas-labels');
    my $atlas_id         = $Hf->get_value('reg-target-atlas-id');
    my $ants_app_dir     = $Hf->get_value('engine-app-ants-dir');
    my $result_dir       = $Hf->get_value('dir-result');
    my @channel_array    = split(',',$Hf->get_value('runno_ch_commalist'));
    my $channel1 = ${channel_array[0]};

    my $channel1_runno   = $Hf->get_value("${channel1}-runno");
    my $channel1_path      = $Hf->get_value("${channel1}-reg2-${atlas_id}-path");
    my $to_deform = $label_dir . "/${atlas_id}_labels.nii"; 

    my $transform_direction = $Hf->get_value('transform_direction');
    my $affine_xform = $Hf->get_value('diff_affine');
    my $warp_xform = $Hf->get_value('diff_warp');
    my $inverse_warp_xform = $Hf->get_value('diff_inv_warp');

    if (! -e $to_deform) {
	error_out("$PM warp_atlas_image: did not find ${atlas_id} labels: $to_deform");
    }
    my $result_path_base = "$result_dir/${channel1}_labels_warp_${channel1_runno}";
    my $result_path      = "$result_path_base\.nii";
    #print ("result path $result_path_base, $channel1_runno, $result_dir --------\n");

    #my $warp_domain_path = $to_deform;
    my $warp_domain_path=$channel1_path;

    my $interp='NearestNeighbor';

    #my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path 
    #-R $warp_domain_path --use-NN $warp_xform\.nii.gz $affine_xform\.txt";
    	my $cmd='';

 if ($transform_direction eq 'i')
	      {
	    #$cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN  -i $affine_xform\.txt $inverse_warp_xform\.nii.gz"; 
          # $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN  -i $affine_xform $inverse_warp_xform\.nii.gz"; 
           $cmd = "$ants_app_dir/antsApplyTransforms -d 3 -i $to_deform -o $result_path -t [ $affine_xform, 1] -t $inverse_warp_xform\.nii.gz -r $warp_domain_path -n $interp";
	      }
           elsif ($transform_direction eq 'f')
	     {
	      #$cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN $warp_xform\.nii.gz $affine_xform\.txt";
            #  $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN $warp_xform\.nii.gz $affine_xform";
              $cmd = "$ants_app_dir/antsApplyTransforms -d 3 -i $to_deform -o $result_path -t $warp_xform\.nii.gz -t [ $affine_xform, 0] -r $warp_domain_path -n $interp";
	     }

    

    print("warp_label_image: $cmd\n");
    if (! execute($ggo, "warp_label_image", $cmd) ) {
	error_out("$PM warp_label_image could not warp: $cmd\n");
    }
    if (!-e $result_path) {
	error_out("$PM warp_label_image: did not find result xform: $result_path");
    }
    
    # in place convert to bytes
    my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";
    if (! execute($ggo, "in place convert label image to Byte", $cmd_byte) ) {
	error_out("$PM to_byte_label_image could not convert: $cmd_byte\n");
    }
#$result_dir/${channel1}-${atlas_id}canon_warp2_${channel1}-${channel1_runno}\_reg2_${atlas_id}
    my ($result_file, $rpath, $rext) = fileparts($result_path);
#reg2_${atlas}_out_label_name
    $Hf->set_value("${channel1}-reg2-${atlas_id}-label-file",$result_file);
    $Hf->set_value("${channel1}-reg2-${atlas_id}-label-path", ${rpath} . ${result_file} . ${rext});
#  my $result_file_id ="${to_deform_id_prefix}-${result_suffix_id}-file";
    return ($result_path);


#add atropos step to increase accuracy. possibly add flag Alex with james help
#use imagemath to genereta mask
#/Volumes/Segmentation/ANTS_20130429_build/bin/ImageMath 3 output_mask ThresholdatMean FA_in 0.001 
#dilate mask by 3 voxels
#/Volumes/Segmentation/ANTS_20130429_build/bin/ImageMath 3 output_mask MD FA_in 3
#/Volumes/Segmentation/ANTS_20130429_build/bin/ImageMath 3 /Volumes/cretespace/N50875_m0Labels-results/N50875_WHS_mask.nii ThresholdAtMean /Volumes/cretespace/N50875_m0Labels-results/N50875_m0_DTI_fa_reg2_dwi_strip_reg2_DTI.nii 0.001 
#try usivariate inititialy since we have lots of classes
#atropos -d 3 -a N50871_fa -i PriorLabelImage[38,labelImage,0.7] -x mask (fromImageMath) -c [10,0.001] -k HistogramParzenWindows[1.32] -m [0.3,1] -o [newlables,posterior%02d.nii.gz] -u 1 -w 
#/Volumes/Segmentation/ANTS_20130429_build/bin/Atropos -d  3 -a /Volumes/pipe_home/whs_references/whs_canonical_images/dti_average/DTI_FA.nii -i PriorLabelImage[ 38,/Volumes/pipe_home/whs_references/whs_labels/dti_average/DTI_labels.nii,0.6] -x /Volumes/cretespace/N50875_m0Labels-results/N50875_WHS_mask.nii -c [ 4,0.01] -k HistogramParzenWindows[ 1,32] -m [ 0.3,1x1x1] -o [ /Volumes/cretespace/N50875_m0Labels-results/dwi_labels_atropos_N50875,posterior%02d.nii.gz] -u 1
#atropos -d 3 -a [ /Volumes/cretespace/test/N50878FA.nii,0.5] -i PriorLabelImage[ 38,/Volumes/cretespace/test/N50878FAlabels.nii,0.8] -x /Volumes/cretespace/test/N50878mask172.nii -c [ 3,0.001] -k Gaussian -m [ 0,1x1x1] -o [ /Volumes/cretespace/test/N50878FAlabelsAtropos.nii,/Volumes/cretespace/test/N50878FAlabelsPostProb.nii ] -u 1 -p Socrates

#./atropos -d 3 -a [ /Volumes/cretespace/test/N50878_m0_DTI_fa_reg2_dwi_strip_reg2_DTI.nii,0.5] -i PriorLabelImage[ 38,/Volumes/cretespace/test/dwi_labels_warp_N50878_m0_cr.nii,0.7 ] -x /Volumes/cretespace/test/N50878maskFullResDil3.nii -c [ 3,0.001] -k Gaussian -m [ 0,1x1x1 ] -o [ /Volumes/cretespace/test/N50878FAlabelsAtroposFullRes.nii,/Volumes/cretespace/test/N50878FAlabelsPostProbFullRes_%d.nii ] -u 1 -p Socrates

}

# ------------------
sub warp_canonical_image { 
# ------------------
# results are for verification, save to working dir
    my ($affine_xform, $inverse_warp_xform, $Hf) = @_;
    print("\n\n\t$PM stage 4/$PM_stages \"warp_canonical_image\" \n\n\n") if ($debug_val >= 35) ;
    my $label_dir = $Hf->get_value('dir-atlas-images');
    my $atlas_id  = $Hf->get_value('reg-target-atlas-id');
    my @channel_array = split(',',$Hf->get_value('runno_ch_commalist'));
    my $channel1 = ${channel_array[0]};
    my $to_deform = $label_dir . "/${atlas_id}_${channel1}.nii"; 
    if (! -e $to_deform) {
	error_out("$PM warp_canonical_image: did not find canonical ${channel1} image: $to_deform");
    }
    my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
    my $channel1_runno   = $Hf->get_value("${channel1}-runno");
    my $warp_domain_path = $Hf->get_value("${channel1}-reg2-${atlas_id}-path");

    my $result_dir       = $Hf->get_value('dir-work');
    my $result_path_base = "$result_dir/${channel1}-${atlas_id}canon_warp2_${channel1}-${channel1_runno}\_reg2_${atlas_id}";
    my $result_path      = "$result_path_base\.nii";
    
    #print ("result path $result_path --------\n");
    #changed feb 26 because the warpsare saved as gz

    #alx feb 26
    #need to make labels byte, and save brain in ${atlas_id} space in results dir

    my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path -i $affine_xform\.txt $inverse_warp_xform\.nii.gz";
    my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";

    if (! execute($ggo, "warp_canonical_image", $cmd) ) {
	error_out("$PM warp_canonical_image could not warp: $cmd\n");
    }

    print "** $PM warp_canonical_image created $result_path\n";

    if (!-e $result_path) {
	error_out("$PM warp_canonical_labels: did not find result xform: $result_path");
    }

    # in place convert to bytes
    my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";
    if (! execute($ggo, "in place convert label image to Byte", $cmd_byte) ) {
	error_out("$PM to_byte_label_image could not convert: $cmd_byte\n");
    }
}


1;
