#!/usr/bin/env python3

MAX_DIS = 241

#######################################
# 1. read alignment distances
dom_dis={}
ifile=open('dis.out')
line = ifile.readline()
dom_id = line[1:-1]
while True:
    line = ifile.readline()
    if not line : break;
    if line.startswith('>'):
        dom_id = line[1:-1]
        continue
    if dom_id not in dom_dis.keys():
        dom_dis[dom_id]=[]
    dom_dis[dom_id].append(float(line[:-1]))


#######################################
# 2. read alignments, sum up the aln matrices

import numpy as np

Pi = np.genfromtxt('vtml/Pi')
sum_aln_mats=[]
for i in range(100):
    sum_aln_mats.append(np.outer(Pi,Pi))    # Laplace smoothing?

AA_TO_INT = {'A': 0 ,'R': 1 ,'N': 2 ,'D': 3 ,'C': 4 ,\
             'Q': 5 ,'E': 6 ,'G': 7 ,'H': 8 ,'I': 9 ,\
             'L': 10,'K': 11,'M': 12,'F': 13,'P': 14,\
             'S': 15,'T': 16,'W': 17,'Y': 18,'V': 19,};

import sys
# dom_ls = open(sys.argv[1]).read().split()
dom_ls = open('index/dom.ls').read().split()

for dom_id in dom_ls:
    ifile=open('../cath/bl_out/'+dom_id)
    ifile.readline()
    dom_seq = ifile.readline()[:-1]
    for dis in dom_dis[dom_id]:
        line = ifile.readline()
        aln_seq = ifile.readline()[:-1]

        dis_index = int(dis/(MAX_DIS/100))

        for i in range(len(aln_seq)):
            if aln_seq[i] == '-':
                continue
            c_i = AA_TO_INT[dom_seq[i]]
            c_j = AA_TO_INT[aln_seq[i]]
            sum_aln_mats[dis_index][c_i][c_j] += 1
            sum_aln_mats[dis_index][c_j][c_i] += 1

    ifile.close()

#######################################
# 3. normalize the sum matrices, write them to files
for i in range(100):
    sum_aln_mats[i] /= np.sum(sum_aln_mats[i])
    out_file_name = 'sum_mat/{:03d}'.format(i)
    np.savetxt(out_file_name,sum_aln_mats[i],'%08e')