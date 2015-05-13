#!/usr/bin/env python3

ifile=open('index/CathDomainList.S35')
domain_ids=[]
for line in ifile:
    domain_ids.append(line.split()[0])
ifile.close()

STA_AA_NAME=set(("ALA","ARG","ASN","ASP","CYS",  \
                 "GLN","GLU","GLY","HIS","ILE",  \
                 "LEU","LYS","MET","PHE","PRO",  \
                 "SER","THR","TRP","TYR","VAL"))

unk_found_ls=[]
for id in domain_ids:
    ifile=open('dompdb/'+id)
    for line in ifile:
        if line[17:20] not in STA_AA_NAME:
            unk_found_ls.append(id)
            print(id)
            break;
    ifile.close()

for id in unk_found_ls:
    ifile=open('dompdb/'+id)
    ofile=open('pdb2/'+id,'w')
    for line in ifile:
        if line[17:20]  in STA_AA_NAME:
            ofile.write(line)
    ifile.close()
    ofile.close()
