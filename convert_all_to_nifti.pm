#!/usr/local/pipeline-link/perl

# convert_all_to_nifti.pm 

# created 2010/11/02 Sally Gewalt CIVM
# calls nifti code that can get dims from header

use strict;
require convert_to_nifti;

# ------------------
sub convert_all_to_nifti {
# ------------------
# convert the source image volumes used in this SOP to nifti format (.nii)
# could use image name (suffix) to figure out datatype
  my ($go, $flip_y, $flip_z, $Hf)  = @_;
  # dimensions are for the SOP acquisition. 
  my $nii_raw_data_type_code = 4; # civm .raw  (short - big endian)
  my $nii_i32_data_type_code = 8; # .i32 output of t2w image set creator 



# -- open, read headfile belonging to  each runno for image params
  my $src_dir = $Hf->get_value('dir_input');
  if (! -d $src_dir) { error_out ("convert_all_to_nifti: no source dir! $src_dir"); }

  my $T1_runno = $Hf->get_value('T1_runno');
  my $input_headfile  = $src_dir . "/". $T1_runno . "/" . "$T1_runno.headfile";
  print "Opening input data headfile: $input_headfile\n";
  my $T1_Hf = new Headfile ('ro', $input_headfile);
  if (! $T1_Hf->check)         {error_out("Problem opening input runno headfile; $input_headfile");}
  if (! $T1_Hf->read_headfile) {error_out("Could not read input runno headfile: $input_headfile");}
  my $input_specid = $T1_Hf->get_value ("U_specid");
  my $xdim = $T1_Hf->get_value ("S_xres_img");
  log_info( "  Specimen id read from T1 input scan $T1_runno headfile: $input_specid\n");
  $Hf->set_value('specid_T1'  , $input_specid);

  convert_to_nifti($go, "T1", $nii_raw_data_type_code, $flip_y, $flip_z, $Hf, $T1_Hf); # .raw 
print ("convert_all_to_nifti: ASSUMING YOUR T2W DATA is 16 bit!!!!!! IF YOU USED the NEW fic program this is OK! If you have older MEFIC processed data go to convert_all_to_nifti and change $nii_raw_data_type_code to $nii_i32_data_type_code (switch lines 53 and 55! \n");

 
  # for fic the result images are .raw
  my $T2W_runno = $Hf->get_value('T2W_runno');;
  my $input_headfile  = $src_dir . "/". $T2W_runno . "/" . "$T2W_runno.headfile";
  print "Opening input data headfile: $input_headfile\n";
  my $T2W_Hf = new Headfile ('ro', $input_headfile);
  if (! $T2W_Hf->check)         {error_out("Problem opening input runno headfile; $input_headfile");}
  if (! $T2W_Hf->read_headfile) {error_out("Could not read input runno headfile: $input_headfile");}
  my $input_specid = $T2W_Hf->get_value ("U_specid");
  log_info( "  Specimen id read from T2W input scan $T2W_runno headfile: $input_specid\n");
  $Hf->set_value('specid_T2W'  , $input_specid);
   #for old MEFIC processed images
  #convert_to_nifti($go, "T2W", $nii_i32_data_type_code, $flip_y, $flip_z, $Hf, $T2W_Hf); # .i32 
  #for newer FIC processed images
  convert_to_nifti($go, "T2W", $nii_raw_data_type_code, $flip_y, $flip_z, $Hf, $T2W_Hf); # .i32 

 

  my $T2star_runno = $Hf->get_value('T2star_runno');
  my $input_headfile  = $src_dir . "/". $T2star_runno . "/" . "$T2star_runno.headfile";
  print "Opening input data headfile: $input_headfile\n";
  my $T2star_Hf = new Headfile ('ro', $input_headfile);
  if (! $T2star_Hf->check)         {error_out("Problem opening input runno headfile; $input_headfile");}
  if (! $T2star_Hf->read_headfile) {error_out("Could not read input runno headfile: $input_headfile");}
  my $input_specid = $T2star_Hf->get_value ("U_specid");
  log_info ("  Specimen id read from T2star input scan $T2star_runno headfile: $input_specid\n");
  $Hf->set_value('specid_T2star'  , $input_specid);
  convert_to_nifti($go, "T2star", $nii_raw_data_type_code, $flip_y, $flip_z, $Hf, $T2star_Hf);  # .raw

  


}


1;

