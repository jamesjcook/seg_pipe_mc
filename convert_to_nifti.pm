#!/usr/local/pipeline-link/perl

# convert_to_nifti.pm 

# created 2009/10/28 Sally Gewalt CIVM

# consider this library for nifti? http://nifti.nimh.nih.gov/pub/dist/src/
# http://afni.nimh.nih.gov/pub/dist/doc/program_help/nifti_tool.html

use strict;

my  $NIFTI_MFUNCTION = 'civm_to_nii_may';  # an mfile function in matlab directory, but no .m here 
  # includes flip_z 
  # note: nii conversion function requires big endian input image data at this time
  # note: function handles up to 999 images in each set now
my $ggo = 1;

# ------------------
sub convert_to_nifti_mc {
# ------------------
# convert the source image volumes used in this SOP to nifti format (.nii)
# could use image name (suffix) to figure out datatype

  my ($go, $data_setid, $data_type_code, $flip_y, $flip_z, $HF_out, $Hf_in) = @_;
  $ggo=$go;

  # the input headfile has image description
  my $xdim    = $Hf_in->get_value('S_xres_img');
  my $ydim    = $Hf_in->get_value('S_yres_img');
  my $zdim    = $Hf_in->get_value('S_zres_img');
  my $xfov_mm = $Hf_in->get_value('RH_xfov');
  print ("  $data_setid header contains dimensions: $xdim, $ydim, $zdim, fov: $xfov_mm, ");
  my $iso_vox_mm = $xfov_mm/$xdim;
  $iso_vox_mm = sprintf("%.4f", $iso_vox_mm);
  print ("ISO_VOX_MM: $iso_vox_mm; ");
  print ("to nifti as datatype code: $data_type_code\n");

  #my $nii_raw_data_type_code = 4; # civm .raw  (short - big endian)
  #my $nii_i32_data_type_code = 8; # .i32 output of t2w image set creator 

  my $nii_setid = nifti_ize_mc ($data_setid, $xdim, $ydim, $zdim, $data_type_code, $iso_vox_mm, $flip_y, $flip_z, $HF_out);
}

# ------------------
sub nifti_ize_mc
# ------------------
{

  my ($setid, $xdim, $ydim, $zdim, $nii_datatype_code, $voxel_size, $flip_y, $flip_z, $Hf_out) = @_;
  
  ###my $runno          = $Hf_out->get_value("$setid\_file");  # runno of civmraw format scan 
  my $runno          = $Hf_out->get_value("$setid\_runno");  #### note this old script uses different item names from newer rigidXXX scripts 
  ###my $src_image_path = $Hf_out->get_value("$setid\_path");
  my $src_image_path = $Hf_out->get_value("$setid\_dir");
  my $dest_dir       = $Hf_out->get_value("dir_work");
  my $image_suffix   = $Hf_out->get_value("$setid\_image_suffix");
  my $image_base     = $Hf_out->get_value("$setid\_image_basename");
  my $padded_digits  = $Hf_out->get_value("$setid\_image_padded_digits");

  ###if ($image_suffix ne 'raw') { error_out("nifti_ize: image suffix $image_suffix not known to be handled by matlab nifti converter (just \.raw)");}
## it can in may?
  $Hf_out->set_value("$setid\_image_suffix", $image_suffix); 
  
  my $dest_nii_file = "$runno\.nii";
  my $dest_nii_path = "$dest_dir/$dest_nii_file";

  # --- handle image filename number padding (.0001, .001).
  # --- figure out the img prefix that the case stmt for the filename will need (inside the nifti.m function)
  #     something like: 'N12345fsimx.0'
  my $ndigits = length($padded_digits);
  if ($ndigits < 3) { error_out("nifti_ize needs fancier padder"); }
  my $padder;
  if ($ndigits > 3) {
    $padder = 0 x ($ndigits - 3);
  }
  else { $padder = ''; }

  my $image_prefix = $image_base . '.' . $padder;


  my $args =
  "\'$src_image_path\', \'$image_prefix\', \'$image_suffix\', \'$dest_nii_path\', $xdim, $ydim, $zdim, $nii_datatype_code, $voxel_size, $flip_y, $flip_z";

  my $cmd =  make_matlab_command ($NIFTI_MFUNCTION, $args, "$setid\_", $Hf_out);   # V2 uses different Hf item names

  if (! execute($ggo, "nifti conversion", $cmd) ) {
    error_out("Matlab could not create nifti file from runno $runno:\n  using $cmd\n");
  }
  if (! -e $dest_nii_path) {
    error_out("Matlab did not create nifti file $dest_nii_path from runno $runno:\n  using $cmd\n");
  }

  # --- required return and setups -----
  my $nii_setid = "$setid\_nii";
  $Hf_out->set_value("$nii_setid\_file", $dest_nii_file);
  $Hf_out->set_value("$nii_setid\_path", $dest_nii_path);
  print "** nifti-ize created [$nii_setid\_path]=$dest_nii_path\n";
  return ($nii_setid);
}

1;

