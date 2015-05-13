################################################################################
#                                                                              #
#                             C.A.T.H                                          #
#                                                                              #
################################################################################

################################################################################
# CATH is a classification of protein domain 3D structures by Orengo CA et al. #
#                                                                              #
# I need CATH for my protein structure prediction projects.                    #
# I need:                                                                      #
#   1. non-redundant domains                                                   #
#   2. residue PSIBlast PSSM                                                   #
#   3. residue secondary structure definitions                                 #
#   4. residue exposure                                                        #
#   5. residue contact definitions                                             #
################################################################################

################################################################################
# 1. Get the CATH files                                                        #
################################################################################

########################################
# 1.1 get the pdb and index files

# the pdb files, 	01-Jul-2013 13:55 	376M
wget http://release.cathdb.info/v4.0.0/CathDomainPdb.S35.tgz
tar xvzf CathDomainPdb.S35.tgz
rm CathDomainPdb.S35.tgz
# 16933 domain files in the dompdb directory

# the index file
mkdir index
wget http://release.cathdb.info/v4.0.0/CathDomainList.S35
mv CathDomainList.S35 index/

awk '{print $1}' index/CathDomainList.S35 | sort  > t1.ls
ls dompdb | sort > t2.ls
diff t1.ls t2.ls 
# all domains have corresponding CATH classification

awk '{print $2 "." $3 "." $4 "." $5}' index/CathDomainList.S35| sort | uniq | wc
# 2738 H classes 

########################################
# 1.2 remove the transmembrane domains 
# The page http://www.cathdb.info/sfam/membrane/ was long gone... 
# Searching keyword 'membrane' on CATH gives 570 H families. Way too much. 

# Search 'membrane' from the CATH domain description file.
# Searching 'transmembrane' won't pick enough. 

wget http://release.cathdb.info/v4.0.0/CathDomainDescriptionFile
grab_description.py | grep membrane | awk '{print $1}' > t1.ls 
rm CathDomainDescriptionFile

awk '{print $1}' index/CathDomainList.S35 > t2.ls 
grab -f t1.ls t2.ls > t.ls
# 275 domains to remove 

grab -v -f t.ls index/CathDomainList.S35 > t.out
mv t.out index/CathDomainList.S35

awk '{print "rm dompdb/" $1}' t.ls > t.sh 
source t.sh 

# 16658 domains left 

################################################################################
# 2. QC the CATH files                                                         #
################################################################################

########################################
# 2.1 check residue names are of the standard types 
# UNK, PCA, ASX etc residues are removed.

mkdir pdb2

rmUnk.py
# 4 pdb domain files need to be fixed ... 
# using psiblast for it. 
# 3e2oA02 seq lptXysl -> lptDysl 
# 3jxvA02 seq lkeXegy -> lkeGegy 
# 3ed7A00 seq LXXXXPPHG -> -----PPHG
# 2yhxA03 too many UNK, remove 

rm -r pdb2 
rm dompdb/2yhxA03
grep -v 2yhxA03 index/CathDomainList.S35 > t.out
mv t.out index/CathDomainList.S35

########################################
# 2.2 check the atoms with negative occupancy

chkOccu.py
# nothing found this time 

########################################
# 2.3 multiple locations of the same atom 

chkMultiLoc.py > t.out 
sort -g -k 2  t.out > t.in
# 916 domains needed to be fixed. 
# 152 of them have more that 10 residues with multiloc atoms 

# download the original PDB files in case...
mkdir rcsb 
awk '{print "wget http://www.rcsb.org/pdb/files/" substr($1,1,4) ".pdb"}' t.in \
    > t.out 
sort t.out | uniq > t.sh 
# 769 pdb files to be downloaded from RCSB 
cd rcsb 
source ../t.sh 
for ifile in *.pdb; do grep "^ATOM " $ifile > t.out; mv t.out $ifile ; done
cd ..

# for atoms with multiloc atoms, the smallest altCode wins.
mkdir pdb2 
rmMultiLoc.py
mv pdb2/* dompdb/
rm -r pdb2 

########################################
# 2.4 check the atoms are not too close to each other

ls dompdb > t.ls 
chkAtomDis.py t.ls > t.in

# it takes some 80 hours. better do it with a cluster. 

# 30 files to fix. 

########################################
# 2.5 check the alternative residue names with the same chain number id

ls dompdb > t.ls  
chkResName.py t.ls 
# nothing found 

########################################
# 2.6 check atoms in the same residue should be close to each other

chkResDis.py t.ls 
# slow. used cluster. 
# two domains fixed . 
# OXT GLU A 135 in 1dqgA00
# OE1 GLN B 240 in 2vqeB01

########################################
# 2.7 check residues (missing CA, N or C atoms)

mkdir pdb2 
chkCANC.py t.ls > t.out 
# 259 out of 16657 domains have some broken residues
# remove the two domains with many breaks
# 1epaA00 160 9 0 9 9
# 1ml9A00 260 10 0 10 10

mv pdb2/* dompdb/
rm -r pdb2
# 16655 domains left

########################################
# 2.8 check for distances between CA and N, CA and C within the same residue

chkResBrk.py t.ls > t.out
# 
# 6 domains to be fixed
# mostly are terminal residues or alternatively located atoms 

########################################
# 2.9 check for segments and breaks of the mainchain. 

#    The distance between the C and the N atoms of the next residue is mostly
#    between 0 and 2.5A (99%) (jumped from 1.67 to 2.68). 
#    That's why I use 2.5A as a threshold here. 
    
chkChainBrk.py t.ls > t.out 
grep file t.out | awk '{print $2,$3,$4,$4/$3}' > t.in 
awk '{print $3}' t.in | sort -g | uniq -c
awk '{print $1,$2 "_" $3 "_" $4 "_" $5 "_" $6}' index/domain.ls > class.in

# 16655 domains, 9357 are fine. 
# 7298 have breaks
# of which 3311 have 1, 1473 have 2, 818 have 3, 1696 have 4 or more

grep file t.out | awk '{if ($4/$3 > 0.05) print $0}' | wc
# 259 domains have breaks number larger then 5% of domain length. 
grep file t.out | awk '{if ($4/$3 > 0.06) print $0}' | wc
# 99  domains have breaks number larger then 6% of domain length. 
grep file t.out | awk '{if ($4/$3 > 0.08) print $0}' | wc 
# 32  domains have breaks number larger then 8% of domain length. 

# remove the 99 domains 
grep file t.out | awk '{if ($4/$3 > 0.06) print $2}' | \
    awk '{print "rm dompdb/" $1}' > t.sh 
source t.sh 
rm t.sh 
ls dompdb > t.ls 
grab -f t.ls index/CathDomainList.S35 > t2.out
mv t2.out index/CathDomainList.S35
# 16556 domains left 

awk '{print $2 "_" $3 "_" $4 "_" $5 }' index/CathDomainList.S35| \
    sort | uniq | wc   
# of the 2700 H families, 21 are removed, 2679 left 

########################################
# 2.10 check the altloc of C, N and CA atoms of the same residue 

chkCNCAaltloc.py t.ls > t.out
# 34 domains to be fixed

chkResAltLoc.py t.ls > t.out
# 205 domains have residues with atoms of different altloc codes
mkdir pdb2
grep pdb2 t.out | awk '{print $(NF-1)}' | \
    awk '{print "cp dompdb/" substr($1,6,7), $1}' | sort | uniq > t.sh
source t.sh

# download the 190 corresponding pdb files from rscb 
# http://www.rcsb.org/pdb/files/1234.pdb

grep "nedit rcsb" t.out | \
    awk '{print "wget  http://www.rcsb.org/pdb/files/" substr($2,6,8)}' | \
    sort | uniq > t.sh 
mkdir rcsb 
cd rcsb
source ../t.sh 
for ifile in *.pdb; do grep "^ATOM " $ifile > t.out; mv t.out $ifile ; done
cd ..

# lots of 'HA A' ... '1.00'
# some    'HB2A' or 'HB3A' ... '1.00'

# after manually fixed the 205 domains 
mv pdb2/* dompdb/
rm -r pdb2 rcsb 

########################################
# 2.11 mapping residue number 

# The QC is almost done here. 

# The residue numbers are messy in PDB files. Different insertion codes,
# chain id changing and alt_loc are troubles to programs like STRIDE and SAP. 
# Give them the uniformed numbering without insert or chain id or altloc.
# 
# However, need to keep a back up copy of this mapping, so that we can get the 
# real residue numbering back if we want.

mkdir res_num_map
ls dompdb > t.ls 
dumpResId.py t.ls 
# pickle dump the residue id mapping
# the residure id mapping is aslo saved into 
index/cath_s35.res_num_map

mkdir pdb2 

chgResId.py t.ls
rm -r dompdb 
mv pdb2 dompdb 

# 16556 domains, 2679 H classes left 
# of the 2679 H classes, 1252 have 1 domain, 460 have 2, 242 3 etc.
# class 2_60_40_10 has 441 member domains. 

################################################################################
# 3. blast the sequences                                                       #
################################################################################

# We need to blast the domain sequences to get PSSMs and fill the gaps between 
# break points.

#######################################
# 3.1 get the initial sequences
mkdir seq   
writeSeq.py t.ls

#######################################
# 3.2 download the nr database 

# Downloaded the nr database from ncbi (ftp://ftp.ncbi.nlm.nih.gov/blast/db/).
# Date: 05/10/12
# It was then filtered to remove various non-globular/biased regions using
# the program pfilt (v1.4) by David T. Jones.

cd ../nr 
nrformat.zsh
# had some warnings from pfilt
# WARNING - description line truncated - increase BUFLEN!
# so...  BUFLEN from 1048576 (2**20) to 2097152 (2**21)
# pfilt.c is from David Jones 

cd ../cath 
#######################################
# 3.3 initial blast of sequences

# download kalign from http://msa.sbc.su.se/downloads/kalign/current.tar.gz
# version 2.04
# install to ~/bin

init_blast.py t.ls
# sometime got 

split -l 100 t.ls 
# put the commandline into t.sh 
# init_blast.py $1 

# t.sh: 
#-----------------------------
# #!/bin/sh
# #$-S /bin/sh
# #$ -cwd
# #$ -q bignode.q,long.q,short.q
# #################################################
# 
# id_ls=$1
# ./init_blast.py $id_ls
#-----------------------------

for lsfile in x?? ; do
    qsub -l h_vmem=10G t.sh $lsfile
done

# It takes 8.5 hours to blast 100 sequences 

mkdir cseq 
calign.py t.ls 
# was using kalign 
# got error messages in kalign such as 
# 25504 Bus error  ~/bin/kalign c_align_in/1avvA00 > c_align/1avvA00
# Failed about 100 times out of 16,556 domains. 
# Used MUSCLE instead.
# MUSCLE is faster, but the output order is not stable. 

# anyway, got the c-seq 

# for comparisons, get the domain sequences with segments seperated with 'x'
mkdir bseq 
ls dompdb > t.ls 

writeBseq.py t.ls 

# 16556 domains, 1-26 breaks per domain
# 9357 have no break, 3310 have 1, 1471 have 2, etc. 
# domain length 14-1146, average 148, median 130 

# 34624 segments, length 1-779, average 71, median 50 
# 18068 breaks

######
# from cseq,  1-25 breaks per domain, average 0.94
# 9690 no break, 3344 1, 1502 2 etc.
# 32144 segments, length 1-759, average 76, median 57
# Of the 16556 domain sequences, 15832 were modified with added residues. 
# That's 95.6%. 

compBreaks.py t.ls 
# with default 0.5 cuts 
# (The query sequence has a gap at the point, and the most occuring amino acid 
# is more than half in the column of the alignment)

# Of the 18068 real domain breaks,
# 6365 have not been assigned (35%)
# 11703 were assgined via calign.py 
# calign.py found 15588 gaps to be filled. 
# 11703 of them are corresponding to real breaks in domains (75%).
# a lot of them are 'm' (5088) and 'x' (2360)
rm -r bseq 

#######################################
# 3.4 get PSSM with the second round of Blast 

# use mostly default parameters. 
# 3 iterations

ls cseq > t.ls 
awk '{print "~/bin/psiblast -db ../nr/nr -num_iterations 3 -query cseq/" $1\
     " -out_ascii_pssm pssm/" $1}' t.ls > t.out 
split -l 100 t.out 

# header ...
head -n 4 t.sh > t.header
for ifile in x?? ; do 
    cat t.header $ifile > t.out; 
    mv t.out $ifile 
done 

for psifile in x?? ; do
    qsub -l h_vmem=10G $psifile
done

getPssm.py t.ls
# or 
split -l 100 t.ls 
for lsfile in x?? ; do
    qsub -l h_vmem=6G t.sh $lsfile
done

# 100 blast jobs took some 18-22 hours 

# two short cseq (1g3iW02 and 1kyiS02) got not blast hits
# Using ncbi blast web server
# It automatically adjust parameters for short input sequences to get some hits.
# So, add options of our psiblast searches for the two 
# -evalue 200000 \
# -word_size 2 \
# -matrix PAM30 \
# -gapopen 9 -gapextend 1 \
# -comp_based_stats 0 \
# -inclusion_ethresh 0.005 \

# 2696068 PSSM for 2696068 residues in cseq 
ls pssm > t.ls 
parse_pssm.py > index/cath_s35.pssm 
rm -r pssm 

# 53921360 values 
# min -16, max 13, mean -1.86, sdv 2.98, median -2
# sounds like -2 +- 3

################################################################################
# 4. DSSP and STRIDE secondary structure definitions                           #
################################################################################

#######################################
# 4.1 run STRIDE and DSSP 

# STRIDE 
# wget http://webclu.bio.wzw.tum.de/stride/stride.tar.gz
# tar xvzf stride.tar.gz
# make
# move stride ~/bin

# DSSP 
# wget ftp://ftp.cmbi.ru.nl/pub/software/dssp/dssp-2.0.4-linux-i386
# mv dssp-2.0.4-linux-i386 ~/bin/dssp 

mkdir stride_ss
ls dompdb > t.ls 
awk '{print "stride dompdb/" $1 " > stride_ss/" $1}' t.ls > t.out 
source ./t.out 

mkdir dssp_ss  
awk '{print "dssp dompdb/" $1 " > dssp_ss/" $1}' t.ls > t2.out 
source ./t2.out 

#######################################
# 4.2 Parse the DSSP and STRIDE definitions

# 110 residues in 107 domains were not assigned by DSSP. 
# (double missing assigments in 3 domains.)
# Just treat them as missing. 
# STRIDE has no such problem. 
# Gap-fill residues in the consensus sequences are obviously missing. 

ls dssp_ss > t.ls 
parse_dssp.py t.ls > index/cath_s35.dssp
#rm -r dssp_ss

ls stride_ss > t.ls 
parse_stride.py t.ls > index/cath_s35.stride 
rm -r stride_ss

# mostly STRIDE and DSSP definitions are similar. 
# average 81% identity
# 40 domains got less than 50% identity
# The mostly dissimilar one is 2kdcA00 (15% identity). 
# DSSP thinks it's mostly H, while STRIDE thinks it's mostly G. 
# I agree with DSSP. 
# Similar story happens on 1hciA04. 

#######################################
# to get 3-states definitions:
# H and G can be considered as helix (H), E and B(b) as strand (E) 
# and all others as coil (C).

#######################################
# to get 7-states definitions

# Neither STRIDE or DSSP want to assign secondary structures to the begin/end of
# a domain. Most are coil, a few begins (5.9%) are assigned to Helix according 
# to STRIDE. 

# From 3 states to 7 states:
# C -> C
# H -> H
# E -> E
# CHH -> Hb -> G
# EHH -> Hb -> G
# HHC -> He -> I
# HHE -> He -> I
# HEE -> Eb -> D
# CEE -> Eb -> D
# EEC -> Ee -> F
# EEH -> Ee -> F

################################################################################
# 4.3 Residue exposure                                                          

# the DSSP solvent accessibility ACC
# modify the parse_dssp.py script a bit 
parse_dssp_acc.py t.ls > index/cath_s35_dssp.acc 
rm -r dssp_ss 

# 2456705 residues with ACC calculated
# min 0, max 379, mean 56.1, sdv 50.7, median 46

# the STRIDE solvent accessibility ACC (EISENHABER et al. 1995)
parse_stride_acc.py t.ls > index/cath_s35_stride.acc
rm -r stride_ss 
# 2456815 residues assigned 
# min 0, max 438.6, mean 56.2, sdv 50.3, median 46.4

# 

################################################################################
# 5. Contact definition                                                        #
################################################################################

#######################################
# 5.1 get residue side-chain and backbone centers. 

# For residues with all side-chain heavy atoms, just use the weight center. 
# For residues with many missing side-chain heavy atoms, use the projection 
# from the C, CA and N atoms.

mkdir ccbc 
ls dompdb > t.ls
g++ getCb.cpp -O4
a.out 

# 2434427 Cb centers calculated
# 22388 guessed. (less than 1%)

#######################################
# 5.2 get the Delaunay tetrahedralization contact definitions.

# The Delaunay tetrahedralization was performed using TetGen v1.4.
# Use only contacts between side-chain centers, which are not blocked by 
# the main-chain to main-chain or side-chain to main-chain contacts.
# Set the distance threshold to 8 A. 

mkdir conDef
g++ -c predicates.cxx -O2
g++ -c tetgen.cxx -O2
g++ getTet.cpp predicates.o tetgen.o -O2

ls dompdb > t.ls
a.out 

parse_condef.py t.ls > index/cath_s35.condef 
# 50-7984 contacts per domain 
# mean 894, median 756, sdv 551
# average 6.02 contacts per residue

rm -r ccbc conDef seq 

################################################################################
# Done                                                                         #
################################################################################