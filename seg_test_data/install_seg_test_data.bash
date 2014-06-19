#!/bin/bash
# remove old copies of testdata work and results
#if  [ -d /`hostname -s`space/TESTDATALabels-results ] 
# then
#    rm -fr /`hostname -s`space/TESTDATALabels-results
# fi
# if [ -d /`hostname -s`space/TESTDATALabels-work ] 
# then
#    rm -fr /`hostname -s`space/TESTDATALabels-work
# fi
# make test data input directories

if [ "X_"$BIGGUS_DISKUS == "X_"e ];
then 
    BIGGUS_DISKUS=/`hostname -s`space/TESTDATALabels-inputs/TESTDATA;
fi
mkdir -p /$BIGGUS_DISKUS/TESTDATALabels-inputs/TESTDATA;
mkdir -p /$BIGGUS_DISKUS/TESTDATALabels-inputs/TESTDATA2;
# place minimum info into dummy headfile for test data with existing nifti's
echo 'U_specid=TEST' > /$BIGGUS_DISKUS/TESTDATALabels-inputs/TESTDATA/TESTDATA.headfile
echo 'U_specid=TEST' > /$BIGGUS_DISKUS/TESTDATALabels-inputs/TESTDATA2/TESTDATA2.headfile
# put dummy image into test data 
touch /$BIGGUS_DISKUS/TESTDATALabels-inputs/TESTDATA/TESTDATAblank.0001.raw
touch /$BIGGUS_DISKUS/TESTDATALabels-inputs/TESTDATA2/TESTDATA2blank.0001.raw

# put test data nifti's into work directory
mkdir -p /$BIGGUS_DISKUS/TESTDATALabels-work
find . -iname "*nii.gz" -exec gunzip {} \;
if [ ! -e ./test.nii ] 
then
  echo "ERROR: test data did not gunzip properly!"
else 
  cp ./test.nii /$BIGGUS_DISKUS/TESTDATALabels-work/TESTDATA.nii
  cp ./test2.nii /$BIGGUS_DISKUS/TESTDATALabels-work/TESTDATA2.nii 
fi
# put test atlas's in place.
read -p 'Where will atlas directories go?' atdir;
cd phant_canonical_images #cd $atdir/phant_canonical_images
ln -s phant_T1.nii phant_T2W.nii 
ln -s phant_T1.nii phant_T2Star.nii 
ln -s phant_T1.nii phant_adc.nii 
ln -s phant_T1.nii phant_dwi.nii 
ln -s phant_T1.nii phant_fa.nii 
ln -s phant_T1.nii phant_e1.nii 
cd ..
cd phant_labels
ln -s ../phant_canonical_images/phant_T1.nii phant_labels.nii
cd ..
cp -RPpn phant_canonical_images $atdir/phant_canonical_images
cp -RPpn phant_labels $atdir/phant_labels

echo "dont forget to use the following options for test runs. "
echo "these are safe to copy paste toegether "
echo "-i $atdir/phant_canonical_images\ "
echo "-l $atdir/phant_labels"

#rm test links from this tes folder 
cd phant_canonical_images #cd $atdir/phant_canonical_images
unlink phant_T2W.nii 
unlink phant_T2Star.nii 
unlink phant_adc.nii 
unlink phant_dwi.nii 
unlink phant_fa.nii 
unlink phant_e1.nii 
cd ..
cd phant_labels
unlink phant_labels.nii
cd ..
#re-gzip our test files
find . -iname "*nii" -exec gzip {} \;