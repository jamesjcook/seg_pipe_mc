#!/usr/local/bin/perl

###call the finction below for all channel comnbinations 



##define functionm

#############################################################
##### define input files and registration prameters ########
#############################################################
my ($name,$name_ref,$prefix1,$prefix2,$param_val, $g1, $g2)=@ARGV;



#system dependent variables
#make directory structure that statss from path_root and contains subdirectories filtered (for input image data); manual_labels; seg_evaluation (output data)
#fiel names are T2_BF_runno.nii or T2FA_BF_ruuno.nii

#on crete
my $path_root="/Volumes/AlexWork/c57_5/braindataby2/bitrate16/"; #"/Volumes/AlexWork/DTI_fromYi/"; 
my $ants_app_dir="/Volumes/Segmentation/ANTS/";
my $path_out="/Volumes/BrainSegPipeline/seg_evaluation/";
my $start_time=time;

#on rhodos
#my $path_root="/Volumes/alex_home/braindata/DTI_fromYi/";
#my $ants_app_dir='/Applications/SegmentationSoftware/ANTS/';

#end system dependent variables


#### define runnos : fixed or "name" (to be labeled), and moving reference or "name_ref" (moving)
     #my name='090417';
     #name='090327';
      #my $name='090529';
     #my $name='090514';
     #my $name='090306';
   ##my $name='090604';
     #name='090430';
     #name='090521';
     #name='mask_090521';
     ##my $name_ref='090521';
my $param_to_optimize="SyN";
#my $param_val=0.8;

#define the two channels
##my $prefix1='T2';
##my $prefix2='RA';

#define registration parameters
#my $metric='PR'; #MI
#my $metric_val=4; 
   my $metric='CC'; 
   my $metric_val=10; 
   my $iterations_diff='3000x3000x3000xx3000';
#${iterations_diff}='1x0x0x0';

    #suggestions
    #TSYNWITHTIME=" -t SyN[0.25,5,0.01] -r Gauss[3,0] " # spatiotemporal (full) diffeomorphism
    #TRANSFORMATION=SyN[1,2,0.05]
    #REGULARIZATION=Gauss[3,0.]
    #TRANSFORMATION=" SyN[1,2,0.05] --geodesic 2 "
    #REGULARIZATION=Gauss[3,0.]
    #/Volumes/alex_home/braindata/DTI_fromYi/filtered/T2_BF_090521.nii


my $path_manual_label="/Volumes/AlexWork/c57_5/manual_labelsby2/bitrate8/cast1_7/"; #"${path_root}manual_labels/";
my $path_auto_label=${path_out}; #"${path_root}seg_evaluation/";

#where your atlas lives
my $path_ref=$path_manual_label; #or keep it somwhere else like on rhodos "/Applications/SegmentationSoftware/alx_can_101103/";
#my $path_ref="/Applications/SegmentationSoftware/alx_can_101103/";



#define output name files (and manual labels for test file (to calculate Dice coefficients against auto_labels
my $auto_label_aff="${path_auto_label}Labels${prefix1}${prefix2}${name}from${name_ref}aff.nii";
my $auto_label="${path_auto_label}Labels${prefix1}${prefix2}${name}from${name_ref}${param_to_optimize}${param_val}${metric}${metric_val}_Gauss${g1}_${g2}m.nii";
my $manual_label="${path_manual_label}${name}labels.nii";  #this one for Dice
my $ref_label="${path_manual_label}${name_ref}labels.nii"; #this one to warp

my $logfile="${path_out}${name}${prefix1}${prefix2}from${name_ref}${param_to_optimize}${param_val}${metric}${metric_val}Gauss_${g1}${g2}m.txt";
   open log_filehandle, "+>$logfile" or die "Can't open logfile $logfile";

my $dicefile="${path_out}Dice${name}${prefix1}${prefix2}from${name_ref}${param_to_optimize}${param_val}${metric}${metric_val}Gauss_${g1}${g2}m.txt";
   open log_dicefilehandle, "+>$dicefile" or die "Can't open dice logfile";
   
   
#open logfile 
   my $start_loop_time=scalar localtime;

print ("this version AlexBadea 2 June 2011");

 @log=("DTI registration with ANTS using ${prefix} \n");
   push @log, "Log opened at $time.", $start_loop_time, "\n", "parame to optimize: ", $param_to_optimize, "\n", "current value: ", $param_val, "\n", "metric: $metric $metric_val \n",  ;
   print log_filehandle @log;
   print @log;
   print ( "\n");



#reconcile headers do only once
###################################
#####can become a function########
##################################
#cd '/Applications/SegmentationSoftware/ANTS/';
#reconcile headers do only once
#/CopyImageHeaderInformation /Applications/SegmentationSoftware/alx_can_101103/rNcanT2sby2_ln.nii /Volumes/alex_home/braindata/DTI_fromYi/filtered/T1_BF_090306.nii /Volumes/alex_home/braindata/DTI_fromYi/filtered/T1_BF_090306.nii 1 1 1

my $reconcile_hdr_name="${ants_app_dir}CopyImageHeaderInformation ${path_ref}rNcanT2sby2_ln.nii ${path_root}${prefix1}_${name}.nii ${path_root}${prefix1}_${name}.nii 1 1 1";
my $reconcile_hdr_ref="${ants_app_dir}CopyImageHeaderInformation ${path_ref}rNcanT2sby2_ln.nii ${path_root}${prefix1}_${name_ref}.nii ${path_root}${prefix1}_${name_ref}.nii 1 1 1";
my $reconcile_log1=`${reconcile_hdr_name}`;
my $reconcile_log2=`${reconcile_hdr_ref}`; 

print log_filehandle ("MAKING Headers compatible - take care of this ahead of time in the future \n");
print log_filehandle ("${reconcile_hdr_name} \n ${reconcile_log1} \n ${reconcile_hdr_ref} \n $reconcile_log2 \n");  
print  ("MAKING Headers compatible - take care of this ahead of time in the future \n ${reconcile_hdr_name} \n ${reconcile_hdr_ref} \n"); 

my $reconcile_hdr_name2="${ants_app_dir}CopyImageHeaderInformation ${path_ref}rNcanT2sby2_ln.nii ${path_root}${prefix2}_${name}.nii ${path_root}${prefix2}_${name}.nii 1 1 1";
 my $reconcile_hdr_ref2="${ants_app_dir}CopyImageHeaderInformation ${path_ref}rNcanT2sby2_ln.nii ${path_root}${prefix2}_${name_ref}.nii ${path_root}${prefix2}_${name_ref}.nii 1 1 1";
my $reconcile_log12=`${reconcile_hdr_name2}`;
my $reconcile_log22=`${reconcile_hdr_ref2}`; 
print log_filehandle ("\n ${reconcile_hdr_name2} \n $reconcile_log12 \n ${reconcile_hdr_ref2} \n ${reconcile_log22} \n ");  
print  ("\n ${reconcile_hdr_name2} \n ${reconcile_hdr_ref2} \n"); 

my $reconcile_hdr_manual_label="${ants_app_dir}CopyImageHeaderInformation ${path_ref}rNcanT2sby2_ln.nii ${manual_label} ${manual_label} 1 1 1";
my $reconcile_log3=`${reconcile_hdr_manual_label}`;
print  ("\n ${reconcile_hdr_manual_label} \n ${reconcile_log3} \n"); 

#same for labels
 

###################################
#####end reconcile headers#########
###################################



#making mask

#check if it exists to not duplicate efforts
my $mask="${path_auto_label}${name}mask.nii";

if (-e $mask) {
 print "Mask File Exists - we skipped mask creation!";
}  
else {
  my $cmd_mask1="${ants_app_dir}ImageMath 3 ${mask} ThresholdAtMean ${manual_label} 0.01";
  my $cmd_mask2="${ants_app_dir}ImageMath 3 ${mask} MD ${mask} 4"; #32 bit mask rather than 8


  my $mask_log1=`${cmd_mask1}`;
  my $mask_log2=`${cmd_mask2}`;

  print log_filehandle ("MAKING BINARY MASK TO REDUCE COMPUTATION TIME \n ${cmd_mask1} \n ${mask_log1} \n"); 
  print log_filehandle ("DILATING BINARY MASK \n ${cmd_mask2} \n ${mask_log2} \n"); 

  print ( " just masking the mask for now to spped up diff reg:\n  ${cmd_mask1}\n ${mask_log1} \n  ${cmd_mask2} \n ${mask_log2} \n");
 } 



#exit;
#afine was using --rigid-affine true with good results! now trying full affine!
#affine registration always uses MI (unless specified otherwise by --afine-metric
my $cmd_reg1="${ants_app_dir}ANTS 3 -m MI[ ${path_root}${prefix1}_${name}.nii,${path_root}${prefix1}_${name_ref}.nii,0.5,300] -m MI[ ${path_root}${prefix2}_${name}.nii,${path_root}${prefix2}_${name_ref}.nii,0.5,300] -o ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name} --MI-option 300x32000 -i 0 --number-of-affine-iterations 3000x3000x3000x3000 -r Gauss[ 3,0] --affine-gradient-descent-option 0.05x0.5x0.0001x0.0001 --use-Histogram-Matching --ignore-void-origin";

my $cmd_reg1="${ants_app_dir}ANTS 3 -m MI[ ${path_root}${prefix1}_${name}.nii,${path_root}${prefix1}_${name_ref}.nii,0.5,300] -m MI[ ${path_root}${prefix2}_${name}.nii,${path_root}${prefix2}_${name_ref}.nii,0.5,300] -o ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name} --MI-option 300x32000 -i 0 --number-of-affine-iterations 3000x3000x3000x3000 -r Gauss[ 3,0] --affine-gradient-descent-option 0.02x0.5x0.0001x0.0001 --use-Histogram-Matching --ignore-void-origin";


#my $cmd_reg1="${ants_app_dir}ANTS 3 -m CC[ ${path_root}${prefix1}_${name}.nii,${path_root}${prefix1}_${name_ref}.nii,0.5,4] -m CC[ ${path_root}${prefix2}_${name}.nii,${path_root}${prefix2}_${name_ref}.nii,0.5,4] -o ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name} --MI-option 300x32000 -i 0 --number-of-affine-iterations 3000x3000x3000x3000 -r Gauss[ 3,0] --affine-metric-type CC --affine-gradient-descent-option 0.05x0.5x0.0001x0.0001 --use-Histogram-Matching --ignore-void-origin";



 print ("starting affine registration with command : \n ${cmd_reg1} \n"); 
 #print ("output affine from initial step:  $cmd_reg1 \n");

#uncomment this Alex
my $reg_log1=`$cmd_reg1`;

print log_filehandle (" affine registration from initial step:  $cmd_reg1 \n $reg_log1\n");
       #log affine command and output text from running it to follow succcess of aff registration
print ("output affine from initial step:  $reg_log1\n");
   
   my $time_reg0 = time;
   my $time_reg = time - $start_time;

 

   print("time given as: ${time_reg0}\n");

   print (" affine reg took: ${time_reg} seconds \n");
   print log_filehandle ("affine reg took: ${time_reg} seconds \n\n\n");
   my $aff_scalar_time=scalar localtime;
   print log_filehandle ("Ended affine registratition at time : $aff_scalar_time\n");
 

my $cmd_warp1="${ants_app_dir}WarpImageMultiTransform 3 ${ref_label} ${auto_label_aff} ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}Affine.txt --use-NN -R ${ref_label}";
my $warp_log1=`$cmd_warp1`;
print log_filehandle ("warping affine labels:  ${cmd_warp1} \n $warp_log1\n");
print ("warping affine labels:  ${cmd_warp1} \n $warp_log1\n");



my $cmd_byte1="${ants_app_dir}ImageMath 3 ${auto_label_aff} Byte ${auto_label_aff}";
my $byte_log1=`$cmd_byte1`;
print (" Byte: ${cmd_byte1} \n");

my $cmd_dice1 = "${ants_app_dir}LabelOverlapMeasures 3 $manual_label $auto_label_aff";


print log_filehandle ("Dice for affine labels calculated as:  $cmd_dice1\n");

 my $dice_txt1=`$cmd_dice1`;
 print (" Dice coeffs: ${dice_txt1} \n");
 print log_dicefilehandle ("Affine registration using MI 200 bins 32000 samples for image type: ${prefix} name: ${name} reference : $name_ref \n param to optimize: $param_to_optimize  $param_val \n ${dice_txt1} \n \n \n");


#TRANSFORMATION=SyN[1,2,0.05]
#REGULARIZATION=Gauss[3,0.]

#we leave the metric choice for diffeomorphic registration only

#my $cmd_diff="${ants_app_dir}ANTS 3 -m ${metric}[ /Volumes/alex_home/braindata/DTI_fromYi/filtered/${prefix}_BF_${name}.nii, /Volumes/alex_home/braindata/DTI_fromYi/filtered/${prefix}_BF_${name_ref}.nii,1,${metric_val}] -x ${mask} -t ${param_to_optimize}[ ${param_val}] -o /Volumes/alex_home/braindata/DTI_fromYi/seg_evaluation/${prefix}${name_ref}_to_${name}${param_to_optimize}${param_val}${metric}m.nii.gz --MI-option 300x32000 -i 1000x1000x1000x0 --number-of-affine-iterations 3000x3000x3000x3000 -r Gauss[ 3,1] --use-Histogram-Matching --affine-gradient-descent-option 0.1x0.5x0.0001x0.0001 -a /Volumes/alex_home/braindata/DTI_fromYi/seg_evaluation/${prefix}${name_ref}_to_${name}Affine.txt --continue-affine true --ignore-void-origin true";


$cmd_diff="${ants_app_dir}ANTS 3 -m ${metric}[ ${path_root}${prefix1}_${name}.nii,${path_root}${prefix1}_${name_ref}.nii,0.5,${metric_val}] -m ${metric}[ ${path_root}${prefix2}_${name}.nii,${path_root}${prefix2}_${name_ref}.nii,0.5,${metric_val}] -x ${mask} -t ${param_to_optimize}[ ${param_val},2,0.05]  --geodesic 2 -o ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}${param_to_optimize}${param_val}${metric}${metric_val}Gauss${g1}_${g2}m.nii.gz --MI-option 300x32000 -i ${iterations_diff} --number-of-affine-iterations 3000x3000x3000x3000 -r Gauss[ ${g1},${g2}] --use-Histogram-Matching --affine-gradient-descent-option 0.05x0.5x0.0001x0.0001 -a ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}Affine.txt --continue-affine true --ignore-void-origin true";

$cmd_diff="${ants_app_dir}ANTS 3 -m ${metric}[ ${path_root}${prefix1}_${name}.nii,${path_root}${prefix1}_${name_ref}.nii,0.5,${metric_val}] -m ${metric}[ ${path_root}${prefix2}_${name}.nii,${path_root}${prefix2}_${name_ref}.nii,0.5,${metric_val}] -x ${mask} -t ${param_to_optimize}[ ${param_val},2,0.05] -o ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}${param_to_optimize}${param_val}${metric}${metric_val}Gauss${g1}_${g2}m.nii.gz --MI-option 300x32000 -i ${iterations_diff} --number-of-affine-iterations 3000x3000x3000x3000 -r Gauss[ ${g1},${g2}] --use-Histogram-Matching --affine-gradient-descent-option 0.05x0.5x0.0001x0.0001 -a ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}Affine.txt --continue-affine true --ignore-void-origin true";


#getting greedy
$cmd_diff="${ants_app_dir}ANTS 3 -m ${metric}[ ${path_root}${prefix1}_${name}.nii,${path_root}${prefix1}_${name_ref}.nii,0.8,${metric_val}] -m ${metric}[ ${path_root}${prefix2}_${name}.nii,${path_root}${prefix2}_${name_ref}.nii,0.4,${metric_val}] -x ${mask} -t ${param_to_optimize}[ ${param_val}] -o ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}${param_to_optimize}${param_val}${metric}${metric_val}Gauss${g1}_${g2}m.nii.gz --MI-option 300x32000 -i ${iterations_diff} --number-of-affine-iterations 3000x3000x3000x3000 -r Gauss[ ${g1},${g2}] --use-Histogram-Matching --affine-gradient-descent-option 0.05x0.5x0.0001x0.0001 -a ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}Affine.txt --continue-affine true --ignore-void-origin true";


print ("diffeomorphic reg command: ${cmd_diff}");

my $diff_log=`$cmd_diff`;
print log_filehandle ("diffeomorphic registration:  ${cmd_diff} \n $diff_log\n");
print  ("diffeomorphic registration:  ${cmd_diff} \n $diff_log\n");


my $time_dreg = time - $start_time;
$time_reg= time -$time_reg0;
print (" diff reg took: ${time_dreg} seconds \n");
   print log_filehandle ("diffeomprphic reg took: ${time_dreg} seconds \n\n\n");
   print log_filehandle ("both reg took: ${time_reg} seconds \n\n\n");
   print "Logfile is: $logfile\n";

# preprocess labels
#./CopyImageHeaderInformation /Volumes/alex_home/braindata/DTI_fromYi/references/alx_can_101103/rNcanT2sby2_cropped.nii /Volumes/alex_home/braindata/DTI_fromYi/manual_labels/FA_${name}rWHS.nii /Volumes/alex_home/braindata/DTI_fromYi/manual_labels/Labels6_${name}rWHS.nii 1 1 1
#./Imagemath 3 /Volumes/alex_home/braindata/DTI_fromYi/manual_labels/Labels6_${name}rWHS.nii Byte /Volumes/alex_home/braindata/DTI_fromYi/manual_labels/Labels6_${name}rWHS.nii 

##./CopyImageHeaderInformation /Volumes/alex_home/braindata/DTI_fromYi/references/alx_can_101103/rNcanT2sby2_cropped.nii /Volumes/alex_home/braindata/DTI_fromYi/manual_labels/${name}rWHS.nii /Volumes/alex_home/braindata/DTI_fromYi/manual_labels${name}rWHS.nii 1 1 1
##./Imagemath 3 /Volumes/alex_home/braindata/DTI_fromYi/manual_labels/${name}rWHS.nii Byte /Volumes/alex_home/braindata/DTI_fromYi/manual_labels/${name}rWHS.nii 



my $cmd_warp="${ants_app_dir}WarpImageMultiTransform 3 ${ref_label} ${auto_label} ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}${param_to_optimize}${param_val}${metric}${metric_val}Gauss${g1}_${g2}mWarp.nii.gz ${path_auto_label}${prefix1}${prefix2}${name_ref}_to_${name}${param_to_optimize}${param_val}${metric}${metric_val}Gauss${g1}_${g2}mAffine.txt --use-NN -R ${ref_label}";

#add Dastins linear interp + median filter

print (" Warp: ${cmd_warp} \n");
my $warp_log=`$cmd_warp`;
print log_filehandle ("warping labels:  ${cmd_warp} \n $warp_log\n");


my $cmd_byte="${ants_app_dir}ImageMath 3 ${auto_label} Byte ${auto_label}";
my $byte_log=`$cmd_byte`;
print (" Byte: ${cmd_byte} \n");


print log_filehandle ("make labels byte:  $cmd_byte \n $byte_log\n");
   my $time_warp = time - $time_reg0;
print (" warp took: ${time_warp} seconds \n");
   print log_filehandle ("warp took: ${time_warp} seconds \n\n\n");
   print "Logfile is: $logfile\n";

 my $cmd_dice = "${ants_app_dir}LabelOverlapMeasures 3 $manual_label $auto_label";
print log_filehandle ("Dice labels calculated as:  $cmd_dice\n");
print log_filehandle ("Dice file is: $dicefile\n");


  print ("Dice calculated as:\n $cmd_dice\n");
 my $dice_txt=`$cmd_dice`;
print (" Dice coeffs: ${dice_txt} \n");
 print log_dicefilehandle ("reference was: $name_ref \n param to optimize: $param_to_optimize  $param_val \n ${dice_txt} \n");
print log_filehandle ("Dice values: ${dice_txt} \n"); 

my $end_time=scalar localtime;
print log_filehandle ("Ended segmentation at time : $end_time\n");

#%ref was /Volumes/alex_home/braindata/DTI_fromYi/references/canon_labels_101103/canon_labels_ln.nii

