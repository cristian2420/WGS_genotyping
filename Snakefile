import pandas as pd

configfile:"snake_conf.yaml"
workdir: config['config']['workdir']


run_file = config['config']['run_file']

gatk_app = config['app']['gatk']
bwa_app = config['app']['bwa']
samtools_app = config['app']['samtools']
bcftools_app = config['app']['bcftools']
picard_app = config['app']['picard']
beagle_app = config['app']['beagle']

try:
    samples_all = pd.read_csv(run_file, header = None, dtype=str)[0].tolist()
    samples_df = list(set([i.replace("reseq", "") for i in samples_all]))
except FileNotFoundError:
    sys.exit('sample run file does not exist!')


try:
    chr_file = pd.read_table(config['config']['bed_genome'], header = None)[0].tolist()
    chr_smll = chr_file[:]
    chr_smll.remove("chrM")
    chr_smll.remove("chrY")
except FileNotFoundError:
    sys.exit('sample run file does not exist!')


donor_dict = {}
for donor in samples_df:
    donor_list = [s for s in samples_all if donor in s]
    sample_dict = {}
    if(len(donor_list) > 1):
        sample_dict["run"] = "2.Processed_data/" + donor_list[0] + "/" + donor_list[0] + "_bwa_mapping_first.bam"
        sample_dict["reseq"] = "2.Processed_data/" + donor_list[1] + "/" + donor_list[1] + "_bwa_mapping_first.bam"
    else:
        sample_dict["run"] = "2.Processed_data/" + donor_list[0] + "/" + donor_list[0] + "_bwa_mapping_first.bam"
    donor_dict[donor] = sample_dict

def bam_dict_from_sample(wildcards):
    return donor_dict[wildcards.sample]


rule all:
    input:
        expand("2.Processed_data/{sample}/{sample}_marked_duplicates.MAPQ20.bam", sample = samples_df),
        expand("2.Processed_data/{sample}/{sample}_marked_duplicates_metrics.txt", sample = samples_df),
        expand("2.Processed_data/{sample}/{sample}_collect_wgs_metrics.txt", sample = samples_df),
        expand("2.Processed_data/{sample}/{sample}_bwa_mapping.metrics.txt", sample = samples_df),
        "3.Results/matrixeqtl/DONE.txt"


rule bwa_mapping:
    input:
        fasta_ref = config['config']['fasta'],
        R1 = "1.Inputs/fastq_input/{sampleAll}_R1.fastq.gz",
        R2 = "1.Inputs/fastq_input/{sampleAll}_R2.fastq.gz"
    output:
        map_file = "2.Processed_data/{sampleAll}/{sampleAll}_bwa_mapping_first.bam"
    params:
        donor = "{sampleAll}"
    threads: 4
    run:
        smlldonor = params.donor
        smlldonor = smlldonor.replace("reseq", "")
        shell("{bwa_app} mem -M -t {threads} -R '@RG\\tID:{smlldonor}\\tSM:{smlldonor}\\tPL:ILLUMINA' {input.fasta_ref} {input.R1} {input.R2} | samtools view -S -bh - > {output.map_file} ")


rule eval_reseq:
    input:
        unpack(bam_dict_from_sample)
    output:
        bam = "2.Processed_data/{sample}/{sample}_bwa_mapping.bam"
    params:
        donor = lambda wildcards: wildcards.sample
    threads: 4
    run:
        if len(input) == 1:
            shell("cp {input.run} {output.bam} ")
        else:
            shell("{samtools_app} merge --threads {threads} {output.bam} {input.run} {input.reseq} ")


rule sortbam:
    input:
        bam_file = "2.Processed_data/{sample}/{sample}_bwa_mapping.bam"
    output:
        bam_sort = "2.Processed_data/{sample}/{sample}_bwa_mapping.sorted.bam"
    threads: 4
    shell:
        "{samtools_app} sort -@ {threads} {input.bam_file} -o {output.bam_sort}"


rule markduplicates:
    input:
        bam_file = "2.Processed_data/{sample}/{sample}_bwa_mapping.sorted.bam"
    output:
        bam_noDup = "2.Processed_data/{sample}/{sample}_marked_duplicates.bam",
        dup_file = "2.Processed_data/{sample}/{sample}_marked_duplicates_metrics.txt"
    params:
        rm_dup = "false"
    shell:
        "java -jar {picard_app} MarkDuplicates I={input.bam_file} "
        "O={output.bam_noDup} M={output.dup_file} REMOVE_DUPLICATES={params.rm_dup} "

rule samstats:
    input:
        bam_file = "2.Processed_data/{sample}/{sample}_bwa_mapping.sorted.bam"
    output:
        txt_file = "2.Processed_data/{sample}/{sample}_bwa_mapping.metrics.txt"
    threads: 4
    shell:
        "{samtools_app} stats  {input.bam_file}  --threads {threads} > {output.txt_file}"

rule collectMetrics:
    input:
        fasta_ref = config['config']['fasta'],
        bam_file = "2.Processed_data/{sample}/{sample}_bwa_mapping.sorted.bam"
    output:
        collect = "2.Processed_data/{sample}/{sample}_collect_wgs_metrics.txt"
    shell:
        "java -jar {picard_app} CollectWgsMetrics I={input.bam_file} "
        "O={output.collect} R={input.fasta_ref} "

rule index_bam:
    input:
        bam_file = "2.Processed_data/{sample}/{sample}_marked_duplicates.bam"
    output:
        index_file = "2.Processed_data/{sample}/{sample}_marked_duplicates.bai"
    shell:
        "{samtools_app} index {input.bam_file} {output.index_file}"


rule baserecal:
    input:
        bam_file = "2.Processed_data/{sample}/{sample}_marked_duplicates.bam",
        bam_index = "2.Processed_data/{sample}/{sample}_marked_duplicates.bai",
        fasta_ref = config['config']['fasta']
    output:
        recal_table = "2.Processed_data/{sample}/{sample}_recal_data.table"
    params:
        snps_1000 = config['gatk_files']["known_SNPs_1000_phase1"],
        indels_Mills = config['gatk_files']["known_indels_from_mills_1000genomes"],
        hg38_indels = config['gatk_files']["known_indels"],
        hg38_snps = config['gatk_files']["know_snps"],
        snps_hapmap = config['gatk_files']["know_SNPs_HapMap"]
    shell:
        "{gatk_app} BaseRecalibrator -I {input.bam_file} -R {input.fasta_ref} "
        " --known-sites {params.snps_1000} --known-sites {params.indels_Mills} "
        " --known-sites {params.hg38_indels} --known-sites {params.hg38_snps} "
        " --known-sites {params.snps_hapmap} -O {output.recal_table} "

rule apply_baserecal:
    input:
        bam = "2.Processed_data/{sample}/{sample}_marked_duplicates.bam",
        fasta_ref = config['config']['fasta'],
        recal_table = "2.Processed_data/{sample}/{sample}_recal_data.table"
    output:
        bamfile = "2.Processed_data/{sample}/{sample}_markdup_bqsr.bam",
        index_file = "2.Processed_data/{sample}/{sample}_markdup_bqsr.bai"
    params:
        tempdir = config['config']['tmp_dir']
    shell:
        "{gatk_app} --java-options \"-Djava.io.tmpdir={params.tempdir} -Xms2G -Xmx2G -XX:ParallelGCThreads=2\" ApplyBQSR "
        " -I {input.bam} -R {input.fasta_ref} "
        " --bqsr-recal-file {input.recal_table} --create-output-bam-index true "
        " -O {output.bamfile}"

rule haplotypecaller:
    input:
        bam_file = "2.Processed_data/{sample}/{sample}_markdup_bqsr.bam",
        index_file = "2.Processed_data/{sample}/{sample}_markdup_bqsr.bai",
        fasta_ref = config['config']['fasta'],
    output:
        vcf_file = "2.Processed_data/{sample}/{sample}_ouput.g.vcf.gz"
    shell:
        "{gatk_app} HaplotypeCaller "
        "-I {input.bam_file} -R {input.fasta_ref} -O {output.vcf_file} -ERC GVCF "


rule bamMAQfilter:
    input:
        bam_file = "2.Processed_data/{sample}/{sample}_marked_duplicates.bam",
        bam_index = "2.Processed_data/{sample}/{sample}_marked_duplicates.bai"
    output:
        filter_bam = "2.Processed_data/{sample}/{sample}_marked_duplicates.MAPQ20.bam"
    shell:
        "{samtools_app} view -hb -q 20 {input.bam_file} > {output.filter_bam}"


rule subset_genome:
    input:
        interval_file = config['config']['bed_genome']
    output:
        chr_file = config['config']['tmp_dir'] + "/{chromosome}.bed"
    params:
        chr = "{chromosome}"
    shell:
        "grep -w {params.chr} {input.interval_file} > {output.chr_file}"


rule genomicsDBImport:
    input:
        vcf_file = expand("2.Processed_data/{sample}/{sample}_ouput.g.vcf.gz", sample=samples_df) ,
        interval_file = config['config']['tmp_dir'] + "/{chromosome}.bed"
    output:
        database = "2.Processed_data/vcf_database_{chromosome}"
    params:
        tempdir = config['config']['tmp_dir'] + '/vcfTempDatabase_{chromosome}/'
    run:
        iFiles = " ".join(["-V " + file for file in input.vcf_file ])
        shell("mkdir -p " + params.tempdir)
        shell("{gatk_app}  GenomicsDBImport " + iFiles + "  --genomicsdb-workspace-path {output.database} -L {input.interval_file} --tmp-dir {params.tempdir}")


rule genotypeGVCFs:
    input:
        fasta_ref = config['config']['fasta'],
        database = "2.Processed_data/vcf_database_{chromosome}"
    output:
        cohort_vcf = "3.Results/chromosome_vcf/cohort_{chromosome}.vcf.gz"
    shell:
        "{gatk_app} --java-options \"-Xmx4g\" GenotypeGVCFs -R {input.fasta_ref} -V gendb://{input.database} -O {output.cohort_vcf}"

rule merge_VCF:
    input:
        vcf_files = expand("3.Results/chromosome_vcf/cohort_{chromosome}.vcf.gz", chromosome = chr_file)
    output:
        cohort = "3.Results/cohort.multiallelic.vcf.gz"
    run:
        iFiles = " ".join(["-I " + file for file in input.vcf_files ])
        shell("java -jar {picard_app} GatherVcfs " + iFiles + " -O {output.cohort} ")

rule multi2biallelic:
    input:
        fasta_ref = config['config']['fasta'],
        vcf_file = "3.Results/cohort.multiallelic.vcf.gz"
    output:
        cohort = "3.Results/cohort.biallelic.vcf.gz"
    shell:
        "{bcftools_app} norm -f {input.fasta_ref} -m -any -Oz -o {output.cohort} {input.vcf_file} "

rule biallelic_index:
    input:
        cohort = "3.Results/cohort.biallelic.vcf.gz"
    output:
        index = "3.Results/cohort.biallelic.vcf.gz.tbi"
    shell:
        "tabix -p vcf {input.cohort} "

rule VariantRecalibrator_SNP:
    input:
        fasta_ref = config['config']['fasta'],
        cohort = "3.Results/cohort.biallelic.vcf.gz",
        index = "3.Results/cohort.biallelic.vcf.gz.tbi",
        snps_hapmap = config['gatk_files']["know_SNPs_HapMap"],
        snps_1000 = config['gatk_files']["known_SNPs_1000_phase1"],
        snps_omni = config['gatk_files']['know_SNPs_OMNI']
    output:
        recal = "3.Results/variant_recalibrator/merged_SNP1.recal",
        tranches = "3.Results/variant_recalibrator/output_SNP1.tranches",
        script = "3.Results/variant_recalibrator/output_SNP1.plots.R"
    params:
        tempdir = config['config']['tmp_dir']
    shell:
        "{gatk_app} --java-options \"-Djava.io.tmpdir={params.tempdir} -Xms4G -Xmx4G -XX:ParallelGCThreads=2\" VariantRecalibrator \
          -tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 \
          -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
          -tranche 95.0 -tranche 94.0 \
          -tranche 93.5 -tranche 93.0 -tranche 92.0 -tranche 91.0 -tranche 90.0 \
          -R {input.fasta_ref} \
          -V {input.cohort} \
          --resource:hapmap,known=false,training=true,truth=true,prior=15.0 {input.snps_hapmap} \
          --resource:omni,known=false,training=true,truth=false,prior=12.0 {input.snps_omni} \
          --resource:1000G,known=false,training=true,truth=false,prior=10.0 {input.snps_1000} \
          -an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR  \
          -mode SNP -O {output.recal} --tranches-file {output.tranches} \
          --rscript-file {output.script} "

rule VariantRecalibrator_Indel:
    input:
        fasta_ref = config['config']['fasta'],
        cohort = "3.Results/cohort.biallelic.vcf.gz",
        index = "3.Results/cohort.biallelic.vcf.gz.tbi",
        indels_Mills = config['gatk_files']["known_indels_from_mills_1000genomes"],
        hg38_snps = config['gatk_files']["know_snps"]
    output:
        recal = "3.Results/variant_recalibrator/merged_indel1.recal",
        tranches = "3.Results/variant_recalibrator/output_indel1.tranches",
        script = "3.Results/variant_recalibrator/output_indel1.plots.R"
    params:
        tempdir = config['config']['tmp_dir']
    shell:
        "{gatk_app} --java-options \"-Djava.io.tmpdir={params.tempdir} -Xms4G -Xmx4G -XX:ParallelGCThreads=2\" VariantRecalibrator \
          -tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 \
          -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 \
          -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 \
          -tranche 92.0 -tranche 91.0 -tranche 90.0 \
          -R {input.fasta_ref} \
          -V {input.cohort} \
          --resource:mills,known=false,training=true,truth=true,prior=12.0 {input.indels_Mills} \
          --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 {input.hg38_snps} \
          -an QD -an MQRankSum -an ReadPosRankSum -an FS -an SOR -an DP \
          -mode INDEL -O {output.recal} --tranches-file {output.tranches} \
          --rscript-file {output.script} "

rule ApplyVQSR_SNP:
    input:
        cohort = "3.Results/cohort.biallelic.vcf.gz",
        recal = "3.Results/variant_recalibrator/merged_SNP1.recal",
        tranches = "3.Results/variant_recalibrator/output_SNP1.tranches"
    output:
        vcf = "3.Results/variant_recalibrator/SNP.recalibrated.vcf.gz"
    params:
        tempdir = config['config']['tmp_dir']
    shell:
        "{gatk_app} --java-options \"-Djava.io.tmpdir={params.tempdir} \
          -Xms2G -Xmx2G -XX:ParallelGCThreads=2\" ApplyVQSR \
          -V {input.cohort} \
          --recal-file {input.recal} \
          -mode SNP \
          --tranches-file {input.tranches} \
          --truth-sensitivity-filter-level 99.8 \
          --create-output-variant-index true \
          -O {output.vcf}"

rule ApplyVQSR_Indel:
    input:
        vcf = "3.Results/variant_recalibrator/SNP.recalibrated.vcf.gz",
        recal = "3.Results/variant_recalibrator/merged_indel1.recal",
        tranches = "3.Results/variant_recalibrator/output_indel1.tranches"
    output:
        vcf = "3.Results/variant_recalibrator/indel.SNP.recalibrated.vcf.gz"
    params:
        tempdir = config['config']['tmp_dir']
    shell:
        "{gatk_app} --java-options \"-Djava.io.tmpdir={params.tempdir} \
          -Xms2G -Xmx2G -XX:ParallelGCThreads=2\" ApplyVQSR \
          -V {input.vcf} \
          -mode INDEL \
          --recal-file {input.recal} \
          --tranches-file {input.tranches} \
          --truth-sensitivity-filter-level 99.9 \
          --create-output-variant-index true \
          -O {output.vcf} "

rule genotypePosteriors:
    input:
        vcf = "3.Results/variant_recalibrator/indel.SNP.recalibrated.vcf.gz",
        wgs_1000GP = config['gatk_files']["wgs_1000GP"]
    output:
        vcf = "3.Results/cohort.genotypePosterior.vcf.gz"
    params:
        tempdir = config['config']['tmp_dir']
    shell:
        "{gatk_app} --java-options \"-Djava.io.tmpdir={params.tempdir} -Xms2G -Xmx2G -XX:ParallelGCThreads=2\" CalculateGenotypePosteriors "
        " -V {input.vcf} "
        " --supporting-callsets {input.wgs_1000GP} -O {output.vcf} "

rule addTag_ID:
    input:
        vcf = "3.Results/cohort.genotypePosterior.vcf.gz"
    output:
        vcf = "3.Results/cohort.tagged.vcf.gz"
    params:
        chr_str = ",".join(chr_smll)
    shell:
        "{bcftools_app} +fill-tags {input.vcf} -Ou | {bcftools_app} view -t {params.chr_str} -Ou | {bcftools_app} annotate --set-id '%CHROM\_%POS\_%REF\_%ALT' -Oz -o {output.vcf} "

rule setup_missing:
    input:
        vcf = "3.Results/cohort.tagged.vcf.gz"
    output:
        vcf = "3.Results/cohort.tagged.missing.vcf.gz"
    shell:
        "{bcftools_app} filter -S . -e 'FMT/DP<3 | FMT/GQ<20' -Oz -o {output.vcf} {input.vcf} "

rule filter_notMAF:
    input:
        vcf = "3.Results/cohort.tagged.missing.vcf.gz"
    output:
        vcf = "3.Results/cohort.filter_notMAF.vcf.gz"
    shell:
        "{bcftools_app} filter -i 'FILTER=\"PASS\"' -Ou {input.vcf}| {bcftools_app} filter -i 'INFO/HWE > 1e-6' -Ou | {bcftools_app} filter -i 'F_MISSING < 0.15' -Oz -o {output.vcf}"

rule imputation:
    input:
        vcf = "3.Results/cohort.filter_notMAF.vcf.gz"
    output:
        vcf = "3.Results/cohort_imputed_file.vcf.gz"
    params:
        prefix = "3.Results/cohort_imputed_file"
    threads: 8
    shell:
        "java -Xmx24g -jar {beagle_app} gt={input.vcf} nthreads={threads} out={params.prefix}  impute=false"

rule index_imputed:
    input:
        "3.Results/cohort_imputed_file.vcf.gz"
    output:
        "3.Results/cohort_imputed_file.vcf.gz.tbi"
    shell:
        "tabix -p vcf {input} "

rule tag_imputed:
    input:
        vcf = "3.Results/cohort_imputed_file.vcf.gz",
        idx = "3.Results/cohort_imputed_file.vcf.gz.tbi"
    output:
        vcf = "3.Results/cohort_imputed_file_tagged.vcf.gz"
    shell:
        "{bcftools_app} +fill-tags  -Oz -o {output.vcf} {input.vcf}"

rule rename_chr:
    input:
        "3.Results/cohort_imputed_file_tagged.vcf.gz"
    output:
        "3.Results/cohort_imputed_file_tagged_rename.vcf.gz"
    params:
        chrs = 'chr_name_conv.txt'
    shell:
        "for chr in {{1..22},X}; do echo chr$\{chr\} $\{chr\} >> {params.chrs}; done"
        "{bcftools_app} annotate --rename-chrs {params.chrs} {input} -Oz -o {output} --set-id '%CHROM\:%POS\:%REF\:%ALT' "

rule filter_maf:
    input:
        vcf = "3.Results/cohort_imputed_file_tagged_rename.vcf.gz"
    output:
        vcf = "3.Results/cohort_MAF_filtered.vcf.gz"
    params:
        maf= config['config']['MAF']
    shell:
        "{bcftools_app} filter -i 'INFO/MAF > {params.maf}' -Oz -o {output.vcf} {input.vcf} "


rule dosage_table:
    input:
        vcf = "3.Results/cohort.MAF_filtered.vcf.gz"
    output:
        table = "3.Results/cohort_genotypeTable.txt"
    shell:
        "{bcftools_app} +dosage {input.vcf} -- -t GT > {output.table}"

rule variants:
    input:
        vcf = "3.Results/cohort.MAF_filtered.vcf.gz"
    output:
        table = "3.Results/variants.txt"
    shell:
        "{bcftools_app} query -f '%ID\n' {input.vcf}  > {output.table}"

rule matrixeqtl_table:
    input:
        genotype = "3.Results/cohort_genotypeTable.txt",
        variants = "3.Results/variants.txt"
    output:
        '3.Results/matrixeqtl/DONE.txt'
    params:
        script = 'bin/matrixeQTL_genFiles.R'
        results = '3.Results/matrixeqtl/'
    shell:
        "Rscript {params.script} -g {input.genotype} -v {input.variants} -r {params.results}"
