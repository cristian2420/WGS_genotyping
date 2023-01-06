#!/usr/bin/R

# ------------------------------------------------------------------------------
# title: Create Matrix eQTL files from vcf genotype
# author: Cristian Gonzalez-Colin
# email: cgonzalez@lji.org
# date: Jan 05, 2023
# ------------------------------------------------------------------------------

library(data.table)

suppressPackageStartupMessages(require(optparse))

option_list = list(
  make_option(c("-g", "--genotype"), action="store", default=NA, type='character',
              help="Genotype file coming from bcftools dosage plugin."),
  make_option(c("-v", "--variants"), action="store", default=NA, type='character',
              help="File with a list of variants."),
  make_option(c("-r", "--resultspath"), action="store", default=NA, type='character',
              help="Output path were files are going to be saved.")
)
opt = parse_args(OptionParser(option_list=option_list))

##debug
if(FALSE){
  opt = list(
      genotype = 'cohort_genotypeTable_MAF0.05.txt',
      variants = 'variants_MAF0.05.txt',
      resultspath = ''
  )
}

genotype <- data.table::fread(opt$genotype)
variants <- readLines(opt$variants)
##pasting files together
names(genotype) <- gsub('\\[.+\\]|#', '', names(genotype))
genotype$variant <- variants

###make matrix eqtl genotype files per chromosome
snps_pos <- genotype[, c('variant','CHROM', 'POS')]
names(snps_pos) <- c('snp', 'chr', 'pos')

snps <- genotype[, c('variant', grep('DLCP', names(genotype), value = T)), with = F]
data.table::setnames(snps, 'variant', 'id')

lapply(unique(snps_pos$chr), function(ID){
  cat('Chromosome: ', ID, '\n')
  pos <- snps_pos[chr == ID]
  snp <- snps[id %in% pos$snp]

  write.table(pos, paste0(opt$resultspath, '/snppos_', ID, '.txt'), quote = F, row.names = F, sep = '\t')
  write.table(snp, paste0(opt$resultspath, 'snp_', ID, '.txt'), quote = F, row.names = F, sep = '\t')
})

writeLines('DONE', paste0(opt$resultspath, '/DONE.txt'))