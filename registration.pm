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
# That is, if we map image B to A using 
# ANTS 2 -m PR[A,B,1,2] -o OUTPUT 
# then we get a deformation called OUTPUTWarp+extensions and an affine transform called 
# OUTPUTAffine.txt. This composite mapping - when applied to B - will transform B into the space of A.
# However, if we have points defined in B that we want to map to A, we have to use OUTPUTInverseWarp and 
# the inverse of OUTPUTAffine.txt.
# --- later in the pdf they show this example: where A is aka the "template.nii", so as above "B is transformed to A"?
#    ANTS 3 -m PR[template.nii.gz,subject.nii.gz,1,2] -i 10x50x50x20 -o subjectmap.nii -t SyN[0.25] -r Gauss[3,0] 
# For the T1 call, -v output calls A fixed and B moving.  
      #  --- is this an inverse transform?  -i 0 ?
      my $opts1 = "-i 0 --use-Histogram-Matching --rigid-affine true --MI-option 32x8000 -r Gauss[3,0.5]";
      #my $opts2 = "--number-of-affine-iterations $affine_iter --affine-gradient-descent-option 0.8x0.5x1.e-4x1.e-4 -v";
     # my $opts2 = "--number-of-affine-iterations $affine_iter --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4 -v --ignore-void-origin "; 
      my $opts2 = "--number-of-affine-iterations $affine_iter --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4 -v";  
      #$cmd = "$ants_app_dir/ANTS 3 -m CC[$A_path,$B_path,1,4] $opts1 -o $result_transform_path_base $opts2"; #option - but time consuming
      $cmd = "$ants_app_dir/ANTS 3 -m MI[$A_path,$B_path,1,32] $opts1 -o $result_transform_path_base $opts2";
      
      
  } elsif ( $xform_code eq 'nonrigid_MSQ' ) {
      # -------- portatlasmask -------------------
      #  --- is this an inverse transform?  -i 0 ?
      my $opts1 = "-i 0 ";
      my $opts2 = "--number-of-affine-iterations $affine_iter --affine-metric-type MSQ";  
#      --affine-gradient-descent-option 0.8x0.5x1.e-4x1.e-4 -v
      $cmd = "$ants_app_dir/ANTS 3 -m MSQ[ $A_path,$B_path,1,2] $opts1 -o $result_transform_path_base $opts2";
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
    apply_affine_transform(@_);
}

# ------------------
sub apply_affine_transform {
# ------------------
  my ($go, $to_deform_path, $result_path, $do_inverse_bool, $transform_path, $warp_domain_path, $ants_app_dir, $interp) =@_; 

### args to wimt: from ants.pdf
# 3  expected image dimension. 
# the image to be deformed. 
# the result deformed image output file name .
# the transform itself is next - if is affine and preceded by " -i ", we apply the inverse affine map. 
# the " -R " option dictates the domain you want to warp into - usually the "fixed" image, unless using 
# the inverse mapping, in which case one switches the role of fixed and moving images. 

# WIMT 3 to_deform_path result_path [-i] transform_path -R warp_domain_path 

  #rpexe2="${ANTSPATH}WarpImageMultiTransform 3 T2s_nii T2sout_image -R T1_in -i fileT2s_out_transform"

  #from rigid_to_can_N32083_30jul.sh
  #exe2="${ANTSPATH}WarpImageMultiTransform 3 /Volumes/alex_home/braindata/whs/T1by2/N32083by2.nii /Users/alex/whs/rN32083.nii -R
  #/Volumes/alex_home/braindata/whs/T1by2/N31238by2.nii -i /Users/alex/whs/rN32083by2Affine.txt"

  my $i_opt = $do_inverse_bool ? '-i' : ''; 
  #my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform_path $result_path -R $warp_domain_path $i_opt $transform_path $interp"; 
  #alex has to use tightest boundign box for macnamara study - different bounding boxes between ref and mc namara images may be adressed this way - or we learn to change the bounding boxes in nii header
  my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform_path $result_path $i_opt $transform_path $interp --tightest-bounding-box"; 

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

