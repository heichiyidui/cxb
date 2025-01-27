#!/usr/bin/env python3
import math
import sys

batch_id = sys.argv[1]
# batch_id = 'b01'

snp_ids = set(open('snp.ls').read().split())

in_call_file = open(batch_id+'/calls.txt')
in_summ_file = open(batch_id+'/summary.txt')

# skip the headers
in_call_file.readline()
in_summ_file.readline()
for line in in_call_file:
    cols = line[:-1].replace('\t-1','\t3').split()
    # I want '3' for missing calls, not '-1'
    snp_id = cols[0]

    snp_calls = cols[1:]
    line_a = in_summ_file.readline()[:-1]
    line_b = in_summ_file.readline()[:-1]

    if snp_id not in snp_ids:
        continue

    log_a = [math.log(float(x),2) for x in line_a.split()[1:]]
    log_b = [math.log(float(x),2) for x in line_b.split()[1:]]

    ofile = open(batch_id+'/'+snp_id+'.avm','w')
    ofile.write('called\tM\tA\n') # header: 'called M A'
    for i in range(len(snp_calls)):
        out_line = snp_calls[i] + '\t' + str(log_a[i]-log_b[i]) + '\t' \
                   + str((log_a[i]+log_b[i])/2) + '\n'
        ofile.write(out_line)
    ofile.close()

in_summ_file.close()
in_call_file.close()
