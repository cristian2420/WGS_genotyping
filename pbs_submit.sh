#!/bin/bash
#PBS -N WGS_snakemake
#PBS -o /path/to/pipeline/WGS_snakemake.out
#PBS -e /path/to/pipeline/WGS_snakemake.err
#PBS -q default
#PBS -l nodes=1:ppn=1
#PBS -l mem=10gb
#PBS -l walltime=120:00:00


### Example on a PBS torque system


code_path=/path/to/wgs/pipeline/
log_path=$code_path/logs

cd ${code_path}
mkdir -p ${log_path}


snakemake --jobs 150 --latency-wait 600 --cluster-config cluster.json --cluster "qsub -l {cluster.walltime} -l {cluster.cores} -l {cluster.memory} -m n -q default -e $log_path/{cluster.error} -o $log_path/{cluster.output}" --jobname 's.{rulename}.{jobid}' --stats $log_path/snakemake.stats >& $log_path/snakemake.log 
