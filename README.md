# WGS_genotyping V2

------
* Cristian Gonzalez-Colin (cgonzalez@lji.org)
* Vijayanand Lab (https://www.lji.org/labs/vijayanand/)
* La Jolla Institute for Immunology (LJI)
* La Jolla, CA USA
* Current version: 2.0 (01/05/2023)
------

## About it

The pipeline was developed for WGS genotyping for the DICE Tissue project (unpublished). It was implemented using [Snakemake](https://snakemake.readthedocs.io/en/stable/) v7.14.0 workflow manager based on GATK Best Practice recommendations and [GTEx](https://www.science.org/doi/10.1126/science.aaz1776) Supplementary Material. Cluster configuration file (cluster.json) needs to be modified according to the cluster/cloud enviroment to work properly.

## Pipeline setup 

The following tools have to be installed on the server. Different versions of these tools may results in different results. Version used is specified in parentheses.

* GATK ([v4.2.2.0](https://gatk.broadinstitute.org/hc/en-us/articles/360036194592-Getting-started-with-GATK4))
* bwa ([v0.7.17](https://bio-bwa.sourceforge.net/))
* samtools ([v1.9](https://github.com/samtools/samtools))
* bcftools ([v1.9](https://github.com/samtools/bcftools))
* picard ([v2.26.1](https://broadinstitute.github.io/picard/))
* beagle ([v5.2](https://faculty.washington.edu/browning/beagle/b5_2.html))
* data.table R library

## Data preparation

### Config file:

Configuration file ```snake_conf.yaml``` has to be in the same folder as the ```Snakefile```. Make proper changes to it.

* **"app":** Locations where the above listed apps were installed.
* **"config":** General directories and parameters.
* **"gatk_files":** GATK reference files downloaded from [https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0/](https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0/)

### Running file:
The running file needs to be specified on the ```snake_conf.yaml``` file as *run_file* in the *config* section. It has to list each sample name to be analyzed. If resequenced samples are provided those have to be name with the prefix *reseq* followed by the sample name. The pipeline will merge samples with this prefix with their respective original sample. Because of this the if *original* and *reseq* for a given sample needs to be listed in the running file.

__E.g.:__

|&nbsp;|
|---|
|sample1|
|sample2|
|sample3|
|reseqsample2|
|&nbsp;|


  
 


