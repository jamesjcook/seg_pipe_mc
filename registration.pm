#!/usr/local/pipeline-link/perl

# registration.pm 

# created 2009/11/19 Sally Gewalt CIVM 

my $PM = "Registration.pm";

use strict;
#use label_brain_pipe; # test_mode variable definiton
use vars qw($test_mode);

# ------------------
sub create_transform {
# ------------------
  my ($go, $xform_code, $A_path, $B_path, $result_transform_path_base, $ants_app_dir) = @_;


  # check for a_path and b_path and add .gz 
  if ( ! -f $A_path ) {
      $A_path=$A_path.".gz";
  }
  if ( ! -f $B_path ) {
      $B_path=$B_path.".gz";
  }   

# ./antsRegistration -d 3 -o /Volumes/cretespace/S64477_m0Labels-work/S64477_m0_DTI_dwi_strip_2_DTIdwi_transform_AffineM.txt -t Rigid[0.25] -c 100x100 -s 4x2vox -f 4x2 -u -m MI[/Volumes/pipe_home/whs_references/whs_canonical_images/dti_average/DTI_dwi.nii,/Volumes/cretespace/S64477_m0Labels-work/S64477_m0_DTI_dwi_strip.nii,1,32,random,0.3]  


  my $affine_iter="3000x3000x3000x3000";
  if (defined $test_mode) {
      if ($test_mode==1) {
	  $affine_iter="1x0x0x0";
      }
  }
  my $cmd;
  if ($xform_code eq 'rigid1') {
      # -------- rigid1 -------------------
      #exe1="${ANTSPATH}ants 3 -m PR[T2s_file_nii,T1_file_nii,1,4] -i 0 --UseHistogramMatching --rigid-affine true --MI-option 16x8000 -r Gauss[3,0] -o 
      #fileT2s_out_transform -number-of-affine-iterations 100x20x10x1 --affine-gradient-descent-option 0.1x0.5x1.e-4x1.e-4 -v"
# --- from ants.pdf: 

      my $opts1 = "-i 0 --use-Histogram-Matching --rigid-affine true --MI-option 32x8000 -r Gauss[3,0.5]";
      #my $opts2 = "--number-of-affine-iterations $affine_iter --affine-gradient-descent-option 0.8x0.5x1.e-4x1.e-4 -v";
     # my $opts2 = "--number-of-affine-iterations $affine_iter --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4 -v --ignore-void-origin "; 
      my $opts2 = "--number-of-affine-iterations $affine_iter --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4 -v";  
      #$cmd = "$ants_app_dir/ANTS 3 -m CC[$A_path,$B_path,1,4] $opts1 -o $result_transform_path_base $opts2"; #option - but time consuming
      

#$cmd = "$ants_app_dir/ANTS 3 -m MI[$A_path,$B_path,1,32] $opts1 -o $result_transform_path_base $opts2";
$cmd = "$ants_app_dir/antsRegistration -d 3 -t Rigid[0.25] -c 3000x3000 -s 4x2vox -f 4x2 -u -m MI[$A_path,$B_path,1,32,random,0.3] -o $result_transform_path_base $opts2";

#example from Brian
#$reg -d $dim -r [ $f, $m ,1] \ -m mattes[ $f, $m , 1 , 32, regular, 0.2 ] \ -t translation[ 0.1 ] \ -c [$its,1.e-8,20] \ -s 4x2x1 \ -f 6x4x2 -l 1 \ -m mattes[ $f, $m , 1 , 32, regular, 0.2 ] \ -t rigid[ 0.1 ] \ -c [$its,1.e-8,20] \ -s 4x2x1 \ -f 6x4x2 -l 1 \ -m mattes[ $f, $m , 1 , 32, regular, 0.2 ] \ -t affine[ 0.1 ] \ -c [$its,1.e-8,20] \ -s 4x2x1 \ -f 6x4x2 -l 1 \ -m mattes[ $f, $m , 1 , 32 ] \ -t syn[ .25, 3, 0.5 ] \ -c [50x50x0,1.e-8,20] \ -s 2x1x0 \ -f 4x2x1 -l 1 -u 1 -z 1 \ -o [${nm},${nm}_diff.nii.gz,${nm}_inv.nii.gz]

#${AP}antsApplyTransforms -d $dim -i $m -r $f -n linear -t ${nm}1Warp.nii.gz -t ${nm}0GenericAffine.mat -o ${nm}_warped.nii.gz
      
 
$cmd = "$ants_app_dir/antsRegistration -d 3 -r [$A_path,$B_path,1] -m Mattes[$A_path,$B_path,1,32,random,0.3] -t translation[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 -m Mattes[$A_path,$B_path,1,32,random,0.3] -t rigid[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 -u 1 -z 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4";
$cmd = "$ants_app_dir/antsRegistration -d 3 -r [$A_path,$B_path,1] -m Mattes[$A_path,$B_path,1,32,random,0.3] -t rigid[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -u 1 -z 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4";
     
  } elsif ( $xform_code eq 'nonrigid_MSQ' ) {
      # -------- portatlasmask -------------------
      #  --- is this an inverse transform?  -i 0 ?
      my $opts1 = "-i 0 ";
      my $opts2 = "--number-of-affine-iterations $affine_iter --affine-metric-type MSQ";  
#      --affine-gradient-descent-option 0.8x0.5x1.e-4x1.e-4 -v
#      --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4";
    #  $cmd = "$ants_app_dir/ANTS 3 -m MSQ[ $A_path,$B_path,1,2] $opts1 -o $result_transform_path_base $opts2";

      #$cmd = "$ants_app_dir/antsRegistration -d 3 -t Affine[0.25] -c 3000x3000 -s 4x2vox -f 4x2 -u -m MeanSquares[$A_path,$B_path,1,4,random,0.3] -o $result_transform_path_base $opts2";
     $cmd = "$ants_app_dir/antsRegistration -d 3 -r [$A_path,$B_path,1] ".
	 " -m MeanSquares[$A_path,$B_path,1,32,random,0.3] -t translation[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 ".
	 " -m MeanSquares[$A_path,$B_path,1,32,random,0.3] -t rigid[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 ".
	 " -m MeanSquares[$A_path,$B_path,1,32,random,0.3] -t affine[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1-u 1 -z 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4";
  }
  else {
      error_out("$PM create_transform: don't understand xform_code: $xform_code\n");
  }
  
  # shorten up the info msg...
  my @list = split '/', $A_path;
  my $A_file = pop @list;
  if (! execute($go, "create $xform_code transform for $A_file", $cmd) ) {
    error_out("$PM create_transform: could not make transform: $cmd\n");
  }
  my $transform_path = "${result_transform_path_base}Affine.txt";

  #which becomes if using antsRegistration
  $transform_path="${result_transform_path_base}0GenericAffine.mat";
  # suffix mentioned on: http://picsl.upenn.edu/ANTS/ioants.php, and confirmed by what appears!
  # note: don't have any dots . in the middle of your base path, just one at the end: .nii

  if (!-e $transform_path && $go) {
    error_out("$PM create_transform: did not find result xform: $transform_path");
    print "** $PM create_transform $xform_code created $transform_path\n";
  }
  return($transform_path);
}
# ------------------
sub apply_transform {
# ------------------
    funct_obsolete("apply_transform", "apply_affine_transform");
    #why needed here alex,  can you not have just apply_affine_tranform or allpy_tranform_tight
    apply_affine_transform(@_);
}

# ------------------
sub apply_affine_transform {
# ------------------
  my ($go, $to_deform_path, $result_path, $do_inverse_bool, $transform_path, $warp_domain_path, $ants_app_dir, $interp) =@_; 

  # check for files, and if not exist assume gzip
  if ( ! -f $warp_domain_path ) {
      $warp_domain_path=$warp_domain_path.".gz";
  }
#rigid reg to atlas calls apply_affine_transform like this:
# apply_affine_transform($ggo, $to_deform_path, $result_path, $do_inverse_bool, $xform_path, $domain_path, $ants_app_dir);


  my $i_opt = $do_inverse_bool ? '-i' : ''; 
  print "i_opt: $i_opt\n";


my $reference='';
my $i_opt1;


# if ($do_inverse_bool eq '-i') {
  if ($i_opt=~ m/i/) {
    $i_opt1=1;
    $reference=$warp_domain_path;
  } else {
    $i_opt1=0;
    $reference=$to_deform_path;
  };


print "interp: $interp\n\n";

   #my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform_path $result_path -R $warp_domain_path $i_opt $transform_path $interp"; 
    # print "warp command: $cmd\n";


  #alex has to use tightest boundign box for macnamara study - different bounding boxes between ref and mc namara images may be adressed this way - or we learn to change the bounding boxes in nii header
  #my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform_path $result_path $i_opt $transform_path $interp --tightest-bounding-box"; 

 #./antsApplyTransforms -d 3 -i /Volumes/cretespace/S64477_m0Labels-work/S64477_m0_DTI_fa_reg2_dwi_strip.nii -o /Volumes/cretespace/S64477_m0Labels-work/S64477_m0_DTI_fa_reg2_dwi_strip_reg2_DTI_ar.nii -t [/Volumes/cretespace/S64477_m0Labels-work/S64477_m0_DTI_dwi_strip_2_DTIdwi_transform_Affine.txt,1]  -r /Volumes/cretespace/S64477_m0Labels-work/S64477_m0_DTI_dwi_strip.nii --use-tightest-bounding-box

#which becomes if using antsRegistration







if ($interp eq '') {
    $interp="LanczosWindowedSinc";
    $interp="Linear";
  } else {
    $interp="NearestNeighbor";
    };

 print "i_opt number: $i_opt1\n";
 print "interpolation: $interp\n";
 print "reference: $reference\n";


#my $cmd="$ants_app_dir/antsApplyTransforms -d 3 -i $to_deform_path -o $result_path -t [$transform_path, $i_opt] -r $to_deform_path --use-tightest-bounding-box -n $interp";
   
my $cmd="$ants_app_dir/antsApplyTransforms --float -d 3 -i $to_deform_path -o $result_path -t [$transform_path, $i_opt1] -r $reference -n $interp";




#example from Brian

#$reg -d $dim -r [ $f, $m ,1] \ -m mattes[ $f, $m , 1 , 32, regular, 0.2 ] \ -t translation[ 0.1 ] \ -c [$its,1.e-8,20] \ -s 4x2x1 \ -f 6x4x2 -l 1 \ -m mattes[ $f, $m , 1 , 32, regular, 0.2 ] \ -t rigid[ 0.1 ] \ -c [$its,1.e-8,20] \ -s 4x2x1 \ -f 6x4x2 -l 1 \ -m mattes[ $f, $m , 1 , 32, regular, 0.2 ] \ -t affine[ 0.1 ] \ -c [$its,1.e-8,20] \ -s 4x2x1 \ -f 6x4x2 -l 1 \ -m mattes[ $f, $m , 1 , 32 ] \ -t syn[ .25, 3, 0.5 ] \ -c [50x50x0,1.e-8,20] \ -s 2x1x0 \ -f 4x2x1 -l 1 -u 1 -z 1 \ -o [${nm},${nm}_diff.nii.gz,${nm}_inv.nii.gz]

#${AP}antsApplyTransforms -d $dim -i $m -r $f -n linear -t ${nm}1Warp.nii.gz -t ${nm}0GenericAffine.mat -o ${nm}_warped.nii.gz


  print " \n";
  print "****applying affine registration:\n $cmd\n";

  my @list = split '/', $transform_path;
  my $transform_file = pop @list;
  if (! execute($go, "$PM: apply transform $transform_file", $cmd) ) {
    error_out("$PM apply_transform: could not apply transform to $to_deform_path: $cmd\n");
  }
  
  if (!-e $result_path) {
    error_out("$PM apply_transform: missing transformed result $result_path");
  }
  print "** $PM apply_transform created $result_path\n";


}


