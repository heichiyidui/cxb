################################################################################
#                Finding variants in PCSK9 affecting LDL-C                     #
################################################################################

################################################################################
#                                                                              #
# The PCSK9 gene blocks LDL (Low-density lipoprotein) receptors. Less LDL      #
# receptor on the surface of liver to remove LDL from bloodstream, leads to    #
# higher LDL cholesterol (LDL-C) concentrations.                               #
# PCSK9 is a fat-control drug target. It is well studied with caucasian        #
# populations.                                                                 #
#                                                                              #
# Now verify our CKB dataset on the detection of SNPs associating with LDL-C   #
# level in this gene.                                                          #
#                                                                              #
################################################################################

# K:\kadoorie\Groups\Genetics\PROJECTS\PCSK9
# PCSK9\ analysis\ plan\ v3.docx

################################################################################
# 1. genotype data                                                             #
################################################################################

################################################################################
# 1.1 the original set

# Start from the stage3 set at
/kuser/shared/data/GWASphase12

plink --bfile /kuser/shared/data/GWASphase12/stage3 \
      --remove /kuser/shared/data/GWASphase12/stage3_mandatory_exclusions.txt \
      --autosome \
      --make-bed --out ckb_ph12_s3

# 636670 variants and 32205 people
# all with unknown father, mother and status
# no repeat in individual G-cryovial ids (ck_ids)

plink --bfile /kuser/shared/data/GWASphase12/stage3 \
      --remove /kuser/shared/data/GWASphase12/stage3_mandatory_exclusions.txt \
      --check-sex
# Obviously, the gender check has been done before.

################################################################################
# 1.2 very basic missing-call and MAF filter

# Do not perform it yet.

# The plan says no QC on SNPs

# plink --bfile ckb_ph12_s3 \
#       --geno 0.05 \
#       --maf  0.0001 \
#       --make-bed --out ckb_ph12_s3_qc01

# # 51983 variants removed due to missing genotype data (--geno).
# # 30961 variants removed due to minor allele threshold(s)
# # 553726 variants and 32205 people left

################################################################################
# 1.3 heterogeneous related to missingness

# Do not remove subjects yet

plink --bfile ckb_ph12_s3_qc01 \
      --het

# No, plink says use a LD-free set.
# I made a comparison. The two sets of F valuse are pretty close.
# But let's just do the LD-pruning

plink --bfile ckb_ph12_s3_qc01 \
      --geno 0.01 \
      --hwe 1e-4 midp \
      --maf 0.05 \
      --indep-pairwise 1500 150 0.2

# 120201 SNPs left

plink --bfile ckb_ph12_s3_qc01 \
      --extract plink.prune.in \
      --make-bed --out t

plink --bfile t  \
      --het

# and missing
plink --bfile ckb_ph12_s3_qc01 \
      --missing

paste plink.het plink.imiss | awk '{print $1,$2,$6,$12}' > t.in

#--------------------------------------
# in R

library(ggplot2)
data = read.table('t.in',header=T)

p1 <- ggplot(data) + geom_point(aes(x=F, y=F_MISS)) + theme_bw()

p2 <- ggplot(data=subset(data,F<0.10), aes(F)) +
      geom_histogram(bins=30) + theme_bw()

threshold = mean(data$F) - 3 * sd(data$F)
data$lowF <- data$F < threshold
# -0.0287 ~ 0.03048 for +-3 SD
# 395 individuals flaged
# or 20 individuals on the lower end

p3 <- ggplot(data,aes(x=lowF, y=F_MISS)) + geom_boxplot( ) + theme_bw()

write.table(subset(data,lowF)$IID,file='low_hom.ls',
            row.names=F,col.names=F,quote=F)
#--------------------------------------
# end of the R script

grab -f low_hom.ls -c 2 ckb_ph12_s3_qc01.fam | awk '{print $1}' | sort | uniq -c
# The plate ids are rather scattered. I was expecting some plate contamination.

# low homozygotes might mean sample contamination.
# The 20 subjects with < 3 x SD F values are of very high missingness.
# 0.022 vs 0.0029 for all subjects
# And, according to the plink IBD estimation,
# these subjects are related to almost EVERYONE else.
# templed to remove them

#######################################
# don't remove any subject here yet

# grab -f low_hom.ls -c 2 ckb_ph12_s3_qc01.fam > t.fam

# plink --bfile ckb_ph12_s3_qc01 \
#       --remove t.fam \
#       --make-bed --out  ckb_ph12_s3_qc02

# # 553726 variants and 32185 people left

################################################################################
# 1.4 IBD and PCA

#######################################
# 1.4.1 LD pruning again

plink --bfile ckb_ph12_s3 \
      --geno 0.01 \
      --maf 0.05 \
      --hwe 1e-4 midp \
      --indep-pairwise 1500 150 0.2

# 120201 SNPs in, 217496 out

plink --bfile ckb_ph12_s3 \
      --extract plink.prune.in \
      --make-bed --out pca

# 120201 variants and 32205 people

#######################################
# 1.4.2 IBD

plink --bfile pca \
      --genome --min 0.05

# 20 minutes on NC2
# plink.genome is huge without the 0.05 filter

tail -n +2 plink.genome | awk '{print $2 "\n" $4}'  | sort | uniq > t.ls
# 32040 subjects to be removed? not acceptable.

tail -n +2 plink.genome | awk '{print $2,$4}' > t.in

select_fam.py > to_remove.ls
# Remove (flag) the subjects according to their degree of connection.
# The most related subjects are to be removed first.
# The top ones are still with low homozygotes.

# 6990 subjects, 22% of 32205

# There are three pairs of people with PI_HAT about 0.5
# CK22775935 CK28153131
# CK28568808 CK28569055
# CK30580964 CK30589772
# The others are a huge family.

# We need to delete all edges. I tried different ad hoc approaches to remove as
# few as possible nodes. I Was doing the PCA with 7333 subjects flagged as
# related. It shouldn't change the results much.

# change the 6th column of pca.fam to 'rel' and 'no_rel'.
grab -f to_remove.ls -c 2 pca.fam | awk '{print $1,$2,$3,$4,$5,"rel"}' > t.out
grab -f to_remove.ls -c 2 pca.fam -v | \
    awk '{print $1,$2,$3,$4,$5,"no_rel"}' >> t.out

awk '{print $2}' pca.fam > t.ls
sort_table -f t.ls -c 2 t.out > t2.out

mv t2.out pca.fam

printf "no_rel\n" > pop.ls

#######################################
# 1.4.3 PCA via EIGENSOFT

# By default, smartpca should be using multithreading now.
# Runing PCA with the un-related subjects only. Then project the factors to the
# related subjects as well.
# Don't remove outliers yet.

nohup /kuser/shared/bin/EIG/bin/smartpca.perl \
        -i pca.bed \
        -a pca.bim \
        -b pca.fam \
        -w pop.ls \
        -o no_rel.pca  \
        -p no_rel.plot \
        -e no_rel.eval \
        -l no_rel.log  \
        -m 0   &

# It took 13G of memory, about 24 hours on nc2.

nohup /kuser/shared/bin/EIG/bin/smartpca.perl \
        -i pca.bed \
        -a pca.bim \
        -b pca.fam \
        -o all.pca  \
        -p all.plot \
        -e all.eval \
        -l all.log  \
        -m 0   &

# 21G of memory, about 48 hours on nc2

#######################################
# 1.4.4 PCA via plink (GCTA)

awk '{print $1,$2,$6}' pca.fam > pca_cluster.in

nohup plink --bfile pca \
            --pca 10 \
            --within pca_cluster.in \
            --pca-cluster-names no_rel &

# plink uses about 80 threads
# 7G of memory
# about 5 hours

################################################################################
# 1.5 final genotype QC

#######################################
# 1.5.1 check the PCA plots

sed 's/\:/\t/' no_rel.pca.evec -i

printf "CK24820387\nCK25228869\nCK28902540\nCK28730586\n" > t.ls

tail -n +2 no_rel.pca.evec |\
    awk '{print $2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13}' | \
    grep -f t.ls -v > t.in

# for ck_id.ls and study_id.ls, see section 2.
sort_table -f ck_id.ls t.in > t.out

printf "study_id rc pc1 pc2 pc3 pc4 pc5 pc6 pc7 pc8 pc9 pc10 is_fam\n" > t.in

paste study_id.ls t.out | \
    awk '{print $1,substr($1,1,2),$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13}' >> t.in

plot_pca.R

###################
# check plink none-relative PCA
awk '{print $6}' pca.fam > t.ls
paste plink.eigenvec t.ls > t.in

printf "CK24820387\nCK25228869\nCK28902540\nCK28730586\n" > t.ls
grep -v -f t.ls t.in > t.out

printf "study_id rc pc1 pc2 pc3 pc4 pc5 pc6 pc7 pc8 pc9 pc10 is_fam\n" > t.in

paste study_id.ls t.out | \
    awk '{print $1,substr($1,1,2),$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,\
         $14}' >> t.in

plot_pca.R

# It seems no outliers are left to be removed.
# PCs are not corresponding to if the subjects are related or not.
# PCs, up to PC7 and PC8, are obviously related to the region codes.

# If we didn't remove the Suzhou (and other) families, they will cousing trouble
# with PCA. PC4-PC10 are all draged by them.


# plink is about 4 times faster than eigensoft.
# They produce mostly the same results.
#

#######################################
# 1.5.2 Remove badly called SNPs found in the manual check.

# Don't do it yet.

# tail -n +2 ../ckb_batch_check/manual_chk_res.table | \
#     awk '{if ($2==0) print $1}' > to_remove_snp.ls

# # 13938 SNPs to be removed.
# # and the four subjects with missing ascertainments

# printf "CK24820387\nCK25228869\nCK28902540\nCK28730586\n" > t.ls

# grab -f t.ls -c 2 ckb_ph12_s3_qc02.fam > t.fam

# plink --bfile ckb_ph12_s3_qc02 \
#       --exclude to_remove_snp.ls \
#       --remove t.fam \
#       --make-bed --out ckb_ph12_s3_qc03
# # 546462 variants and 32181 people

################################################################################
# 2. phenotype data                                                            #
################################################################################

################################################################################
# 2.1 to get study ids

awk '{print $2}' pca.fam > ck_id.ls
# 32205 uniq ids in ck_id.ls

# 32410 subject ascerntaiments from
# GWAS_SNPdata_samples.xlsx in
# K:\kadoorie\Groups\Genetics\Data Archive\Project Sample Lists\Lists\

# The ids in the 'notes' column are absent from the ids obtained using the data
# request form. We removed this column.

# Some G-cryovial ids are of different format with the ids in the fam file.
# CK28185397-1 vs CK28185397-QC
# CK22754927-1 vs CK22754927-1-QC
# etc
# Changed the ids in the ascertainment file to confirm the plink fam files.

# 4 subjects in ckb_ph12_s3.fam are not found in the ascertainment files:
# CK24820387 CK25228869 CK28902540 CK28730586
# They were to be deleted from the genotype set?

# The modified and sorted file
GWAS_SNPdata_samples.csv

printf "CK24820387\nCK25228869\nCK28902540\nCK28730586\n" > t.ls
grep -f t.ls -v GWAS_SNPdata_samples.csv > t.out
mv t.out GWAS_SNPdata_samples.csv

skh  GWAS_SNPdata_samples.csv | awk -F"," '{print $1}' > ck_id.ls
skh  GWAS_SNPdata_samples.csv | awk -F"," '{print $2}' > study_id.ls

# 32201 uniq study and ck id pairs.
# ck_id.ls and study_id.ls were used in 1.5.1

################################################################################
# 2.2 stratification

# use the sheet 2 of PCSK9_sample_summary.xlsx from
# K:\kadoorie\Groups\Genetics\PROJECTS\PCSK9
# for subject stratification.
# Added 1288 '0's in the 'pass GWAS QC' column according to study_id.ls
# instead of 1275 in the original one.

# simplified table with header:
# studyid ascert still_OK dir_ldl_base dir_ldl_rs1 dir_ldl_rs2 indir_ldl_rs2

# use LDL-c_biochem_data.xlsx for direct LDL-C
# use ldl_levels_resurvey2_latest.xls for indirect LDL-C
# scale indirect ldl-c by 0.01
# 18091 direct and 7110 indirect measures

# indirect ldl-c is smaller
# mean 2.120 vs 2.376
# t-test says the difference is very significant.

PCSK9_sample_summary.csv

# put the first 7 columns of PCSK9_sample_summary.csv into t.in
# and prepare the other input files:
# age_base.csv
# age_resu1.csv
# age_resu2.csv
# direct_ldl_c.txt
# indirect_ldl_c.txt

get_strat.py > t.out


# str1: ICH     direct       4762
# str2: IS      direct       5210
# str3: SAH     direct        167
# str4: MI/IHD  direct       1265
# str5: control direct       6696
# str6: all indirect left    4174

# others: 11205 NA


################################################################################
# 2.3  Covariates and phenotypes

#######################################
# 2.3.1 The phenotype file is easy to make.
pheno.csv
# FID IID LDL
# 21553 subject LDL measures

#######################################
# 2.3.2 The covariates file

# use plink no-rel 10 PCs

# using the data request form to get the age_at_study info.
# ages of 3 subjects are missing:
# CK28728060      580282304
# CK28728462      580281490
# CK30579300-1    580235861

# 1377 12 Qingdao   rc1
# 3285 16 Harbin    rc2
# 1164 26 Haikou    rc3
# 1695 36 Suzhou    rc4
# 2424 46 Liuzhou   rc5
# 4090 52 Sichuan   rc6
# 4675 58 Gansu     rc7
# 4324 68 Henan     rc8
# 3336 78 Zhejiang  rc9
# 5831 88 Hunan     Hunan will be absent from RC factors

printf "CK24820387\nCK25228869\nCK28902540\nCK28730586\n" > t.ls

tail -n +2 no_rel.pca.evec |\
    awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12}' | \
    grep -f t.ls -v > t.in

paste study_id.ls t.in | sed 's/\t/\ /' > t.out

# ...

cov.csv

# 'NA' to -9 for missing covariates (age)
# Given the stratification only 4 subjects have missing ages.

# don't forget keep-pheno-on-missing-cov

################################################################################
# 3. plink linear regression                                                   #
################################################################################

# get the sets
awk '{if ($8==1) print $1}' PCSK9_sample_summary.csv > t1.ls ;
grab -f t1.ls -c 2 pca.fam > t1.fam ;
plink --bfile ckb_ph12_s3 --keep t1.fam --make-bed --out st1 &
awk '{if ($8==2) print $1}' PCSK9_sample_summary.csv > t2.ls ;
grab -f t2.ls -c 2 pca.fam > t2.fam ;
plink --bfile ckb_ph12_s3 --keep t2.fam --make-bed --out st2 &
awk '{if ($8==3) print $1}' PCSK9_sample_summary.csv > t3.ls ;
grab -f t3.ls -c 2 pca.fam > t3.fam ;
plink --bfile ckb_ph12_s3 --keep t3.fam --make-bed --out st3 &
awk '{if ($8==4) print $1}' PCSK9_sample_summary.csv > t4.ls ;
grab -f t4.ls -c 2 pca.fam > t4.fam ;
plink --bfile ckb_ph12_s3 --keep t4.fam --make-bed --out st4 &
awk '{if ($8==5) print $1}' PCSK9_sample_summary.csv > t5.ls ;
grab -f t5.ls -c 2 pca.fam > t5.fam ;
plink --bfile ckb_ph12_s3 --keep t5.fam --make-bed --out st5 &
awk '{if ($8==6) print $1}' PCSK9_sample_summary.csv > t6.ls ;
grab -f t6.ls -c 2 pca.fam > t6.fam ;
plink --bfile ckb_ph12_s3 --keep t6.fam --make-bed --out st6 &

# linear regression with all covariants
for st in st1 st2 st4 st5 st6 ; do
    nohup plink --bfile $st \
      --pheno pheno.csv \
      --pheno-name LDL \
      --covar cov.csv keep-pheno-on-missing-cov \
      --linear hide-covar --ci 0.95 \
      --out $st &
done

# The SAH cohort is way too small.
# With all covariants the output will be all NA.
nohup plink --bfile st3 \
  --pheno pheno.csv \
  --pheno-name LDL \
  --covar cov.csv keep-pheno-on-missing-cov \
  --covar-name sex,age,pc1,pc2 \
  --linear hide-covar --ci 0.95 \
  --out st3 &

#######################################
# format the output

for st in st1 st2 st3 st4 st5 st6 ; do
    head -n 1 $st.assoc.linear > t.out
    grep ADD $st.assoc.linear | grep -v NA >> t.out
    mv t.out $st.assoc.linear
done

# put A2 into the tables
for st in st1 st2 st3 st4 st5 st6 ; do
    add_a2.py $st.assoc.linear > t.out
    mv t.out $st.assoc.linear
done

#######################################
# QQ and Manhattan plots and lambda

# let's have a look
for st in st1 st2 st3 st4 st5 st6 ; do
    plot_qq_man.R $st.assoc.linear &
done

# to calculate lambda
# lambda.R
#--------------------------------------
#!/usr/bin/Rscript

args = commandArgs(trailingOnly=TRUE)
ifile_name = args[1]

data=read.table(ifile_name,header=T)
data=subset(data,!is.na(P))

chisq <- qchisq(1-data$P,1)
lambda = median(chisq)/qchisq(0.5,1)
cat(args[1],'lambda: ',lambda,'\n')
#--------------------------------------

for st in st1 st2 st3 st4 st5 st6 ; do
    lambda.R $st.assoc.linear
done

# st1.assoc.linear lambda:  1.007485
# st2.assoc.linear lambda:  1.008424
# st3.assoc.linear lambda:  0.9920914
# st4.assoc.linear lambda:  0.9907005
# st5.assoc.linear lambda:  1.025426
# st6.assoc.linear lambda:  1.008893

################################################################################
# 4. METAL analysis                                                            #
################################################################################

# We can use plink for some very simple meta-analysis
# plink --meta-analysis  st6.assoc.linear st3.assoc.linear + qt

t_metal.sh
# direct vs indirect , HetPVal lambda = 0.9102188

# prepare for plotting
awk '{print $1}' pcsk9_direct1.tbl | t -n +2 > t.ls
grab -f t.ls -c 2 ckb_ph12_s3.bim | awk '{print $1,$2,$4} ' > t.in
sort_table -f t.ls -c 2 t.in > t.out

mv t.out t.in
t -n +2 pcsk9_direct1.tbl > t2.in
printf "CHR SNP BP A1 A2 BETA SE P DIR\n" > pcsk9_direct_metal.out
paste t.in t2.in | \
     awk '{print $1,$2,$3,$5,$6,$7,$8,$9,$10}'>> pcsk9_direct_metal.out



awk '{print $1}' pcsk9_all1.tbl | t -n +2 > t.ls
grab -f t.ls -c 2 ckb_ph12_s3.bim | awk '{print $1,$2,$4} ' > t.in
sort_table -f t.ls -c 2 t.in > t.out

mv t.out t.in
t -n +2 pcsk9_all1.tbl > t2.in
printf "CHR SNP BP A1 A2 BETA SE P DIR\n" > pcsk9_all_metal.out
paste t.in t2.in | \
     awk '{print $1,$2,$3,$5,$6,$7,$8,$9,$10}'>> pcsk9_all_metal.out

plot_qq_man.R pcsk9_direct_metal.out
plot_qq_man.R pcsk9_all_metal.out

################################################################################
# 5. linear again and metal again                                              #
################################################################################

################################################################################
# 5.1 ldl-c rank inverse-normal transformed

rint.R

# and put the results into pheno.csv
# 4 ages are missing, so 4 more ldl measures are gone.

################################################################################
# 5.2 the genotype file. We now look at pcsk9 region only
plink --bfile ckb_ph12_s3 \
      --from AX-105169173 --to AX-31657601 \
      --make-bed --out geno
# 166 variants and 32205 people
# 6 SNPs with '0' in genotype are cousing trouble. Exclude them.
# 160 variants and 32205 people

awk '{print $2}' geno.bim > snp.ls

# check ld
plink --bfile geno \
       --r2 --ld-snp AX-83389438 \
       --ld-window-r2 0 \
       --ld-window 99999 \
       --ld-window-kb 177000

# nothing is in LD with AX-83389438
# highest of all but itself is 0.0140177

# and ld for AX-11576926 and AX-39912161

# Axiom_CKB_1_variant_list.xlsx from
# K:\kadoorie\Groups\Genetics\Data Archive\Array_design_ver1\


# save into snp.ld

# AX-83389438 is rs151193009
# It is presented only in CHB, CHS, JPT and KHV cohorts in 1000G phase 3, with
# MAF around 1.3%.
# It is causing the 93R->C mutation in the protein.

# exon 2

# Found in http://www.sciencedirect.com/science/article/pii/S0021915007000512
#                                 LOW LDL         HIGH LDL
# c.277C > T    Exon 2    R93C    70    8    0    95    1    0
# P-value by Fisher's exact test was 0.003
# only missense mutation found
# Japan, general population (n = 3655)
pic/pcsk9_ldlr_93R_pdb.ps
# The 93R residue is nowhere close to the binding site!

################################################################################
# 5.3 linear regression

# raw analysisi
for st in st1 st2 st4 st5 st6 ; do
    plink --bfile geno \
      --keep $st.fam \
      --pheno pheno.csv \
      --pheno-name LDL \
      --covar cov.csv keep-pheno-on-missing-cov \
      --linear hide-covar --ci 0.95 \
      --out $st.raw &
done

plink --bfile geno \
  --keep st3.fam \
  --pheno pheno.csv \
  --pheno-name LDL \
  --covar cov.csv keep-pheno-on-missing-cov \
  --covar-name sex,age,pc1,pc2 \
  --linear hide-covar --ci 0.95 \
  --out st3.raw

# standard-beta
for st in st1 st2 st4 st5 st6 ; do
	std_beta.py $st.raw.assoc.linear > t.out
	mv t.out $st.std.assoc.linear
done


# rint_ldl
plink --bfile geno \
  --pheno pheno.csv \
  --pheno-name rint_LDL \
  --covar cov.csv keep-pheno-on-missing-cov \
  --covar-name pc1-pc10 \
  --linear hide-covar --ci 0.95 \
  --out rint_ldl
# to make sure standard beta in rint_ldl
std_beta.py rint_ldl.assoc.linear > t.out
mv t.out rint_ldl.assoc.linear


################################################################################
# 5.4 meta analysis

# put A2 into the tables
for ifile in *.assoc.linear ; do
    add_a2.py $ifile > t.out
    mv t.out $ifile
done

full_metal.sh

################################################################################
# 5.5 plot them

plot_metal.R

metal_results.csv

# SNPs AX-105027908 and AX-83302687 are giving NA results, removed them


################################################################################
# 6. direct strata only                                                        #
################################################################################

# Finding variants in PCSK9 affecting LDL-C

# Given the biochemistry direct measures of LDL-C (Low-Density Lipoprotein
# Cholesterol) concentration, and the SNP genotype data, we can perform
# association studies to identify relevant genes, and their genetic variants.
#
# PCSK9 (proprotein convertase subtilisin/kexin type 9) is a fat-control drug
# target, well studied with Caucasian populations. The gene blocks LDL-C
# receptors on the surface of liver. Less active receptor removing LDL-C from
# bloodstream leads to higher LDL-C concentration and increased risk of
# cardiovascular events. Drugs targeting PCSK9 have been developed to reduce
# LDL-C concentration in blood.
#
# Given some Caucasian PCSK9 variants identified as associated with LDL-C are
# absent from or present at low frequencies in Chinese, we seek to identify
# additional PCSK9 variants associated with LDL-C levels in Chinese populations.
#

################################################################################
# now let's look at the direct measures only


#            ascert   size    lambda
# stratum_1  ICH      4762    1.007
# stratum_2  IS       5210    1.008
# stratum_3  SAH       167    0.992
# stratum_4  MI/IHD   1265    0.991
# stratum_5  control  6696    1.025

# With stratum 3 (ascertainment SAH), because of the small cohort size, we used
# covariates sex, age, PC1 and PC2 only. With other strata, sex, age, PC1-10 and
# RC were employed as covriates.

################################################################################
# first starts without using SNP's allelic dosage as a covariate,
printf "" > c_snp.ls

for st in st1 st2 st4 st5 ; do
    plink --bfile geno \
      --keep $st.fam \
      --pheno pheno.csv \
      --pheno-name LDL \
      --covar cov.csv \
      --linear hide-covar --ci 0.95 \
      --condition-list c_snp.ls \
      --out $st.raw
done

plink --bfile geno \
  --keep st3.fam   \
  --pheno pheno.csv \
  --pheno-name LDL  \
  --covar cov.csv  \
  --covar-name sex,age,pc1,pc2 \
  --linear hide-covar --ci 0.95 \
  --condition-list c_snp.ls \
  --out st3.raw

for st in st1 st2 st3 st4 st5 ; do
    add_a2.py $st.raw.assoc.linear > t.out
    mv t.out $st.raw.assoc.linear
done

metal < t_metal.sh

# collect the columns together and sort them
parse_meta_out.py > t.in
head -n 1 t.in > t.out
tail -n +2 t.in | sort -g -k 11 >> t.out
mv t.out t.in

# plot them
plot_meta_p_q.R

cp t.in  meta_0.in
cp t.png meta_0.png
################################################################################
# add SNPs now

for i in {1..5} ; do
    tail -n +2 t.in | sort -g -k 11 | awk '{if (NR==1) print $1}' >> c_snp.ls
    t.sh
    cp t.in meta_$i.in
    cp t.png meta_$i.png
done

# SNPs removed
# AX-83389438
# AX-31642001
# AX-11541856
# AX-31642169


# Two SNPs are in the 384 panel.

# With AX-11150762 the P values are 0.04063 0.01933 and 0.05688
# in meta_0, meta_1 and meta_2
# With AX-39911995 nothing found.

# AX-11150762 rs11206510
# meta_0.in  1 55496039 0.05637 T C 0.0308 0.0151 0.4555 +++-+ 0.04063
# meta_1.in  1 55496039 0.05637 T C 0.0351 0.0150 0.4839 +++-+ 0.01933
# meta_2.in  1 55496039 0.05637 T C 0.0287 0.0151 0.4496 +++-+ 0.05688
# meta_3.in  1 55496039 0.05637 T C 0.0245 0.0151 0.4445 +++-+ 0.1048

# AX-39911995 rs2479409
# meta_0.in  1 55504650 0.3181 A G -0.0073 0.0075 0.5959 ---+- 0.3301
# meta_1.in  1 55504650 0.3181 A G -0.0156 0.0075 0.5641 ---+- 0.0378
# meta_2.in  1 55504650 0.3181 A G -0.0124 0.0076 0.5271 ---+- 0.1011
# meta_3.in  1 55504650 0.3181 A G -0.0148 0.0076 0.4978 ---+- 0.05061

################################################################################
# RINT phenotype
# now just switch --pheno-name LDL to --pheno-name rint_LDL
# and --covar-name pc1-pc10 line


# SNPs removed
# AX-83389438
# AX-39912161
# AX-11576926
# AX-64101281

# different order of remving the second got the third very different.
# If we did select SNP AX-31642001 in the second round (it was a close match),
# we would end up with exactly the same selection.

# If we selected AX-31642001 after the top hit, the next one will be AX-64101281
# But all are of large P values. (2*10^-3)

# The 384 panel SNPs

# AX-11150762 rs11206510
# meta_0.in 1 55496039 0.05637 T C 0.0444 0.0228 0.5506 +++-+ 0.05113
# meta_1.in 1 55496039 0.05637 T C 0.0514 0.0227 0.5647 +++-+ 0.02332
# meta_2.in 1 55496039 0.05637 T C 0.0132 0.0238 0.5117 +-+-+ 0.579
# meta_3.in 1 55496039 0.05637 T C 0.0166 0.0238 0.5042 +-+-+ 0.4857

# AX-39911995 rs2479409
# meta_0.in 1 55504650 0.3181 A G -0.0117 0.0114 0.7847 ---+- 0.3039
# meta_1.in 1 55504650 0.3181 A G -0.0249 0.0113 0.7438 ---+- 0.02813
# meta_2.in 1 55504650 0.3181 A G -0.0096 0.0117 0.7401 ---+- 0.4134
# meta_3.in 1 55504650 0.3181 A G -0.0118 0.0117 0.7811 --++- 0.3156

################################################################################
# 7. Re-check the indirect LDL measures                                        #
################################################################################

# using the data request form to get snapshort 10 ldl data
# got 19423 numbers, scared by 1/100.

# 7114 got study_id of the genotype set
# The correlation coefficient is 0.35 very significant, but not high ...


get_strata.py > t.in
rint.R
# The table generated is in the file 't.out'.
# Maybe re-order the table according to the fam file?
awk '{print $2}' ckb_ph12_s3.fam > t.ls
sort_table -f t.ls t.out -c 2 -sh | grep -v NA > pheno.csv


# use plink no-rel 10 PCs and the pheno.csv for covariates
get_cov.py | sed 's/\ /\t/g' > cov.csv


################################################################################
