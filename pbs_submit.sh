#!/bin/bash
#SBATCH --job-name=multiple_eQTL
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=10g
#SBATCH --time=120:00:00
#SBATCH --output=/path/to/sdoutput/pcs.out
#SBATCH --error=/path/to/sderr/pcs.err

cd /path/to/pipeline

WORKDIR=/path/workingdirectory/eQTL_pipeline/
log_path=${WORKDIR}/logs/

start=`date +%s`
date


snakemake --jobs 100 --latency-wait 60 --snakefile Snakefile --configfile snake_conf.yaml --cluster-config cluster.json --cluster "sbatch --time={cluster.walltime} --nodes=1 --ntasks=1 --cpus-per-task=4 --mem={cluster.memory} -e /${log_path}/{rule}.{jobid}.{wildcards}.err -o /${log_path}/{rule}.{jobid}.{wildcards}.out --export ALL --parsable" --stats $log_path/snakemake.stats >& $log_path/snakemake.log  --rerun-incomplete --use-conda --cluster-status smk-slurm.sh 

end=`date +%s`
runtime=$((end-start))
echo 'Running time ' ${runtime} ' seconds'
