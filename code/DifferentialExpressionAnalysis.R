options(stringsAsFactors = FALSE)
# import data if sample are small
control <- read.table("F:/Data/RNA-Seq/matrix/SRR3589956.count", 
                       sep="\t", col.names = c("gene_id","control"))
rep1 <- read.table("F:/Data/RNA-Seq/matrix/SRR3589957.count", 
                    sep="\t", col.names = c("gene_id","rep1"))
rep2 <- read.table("F:/Data/RNA-Seq/matrix/SRR3589958.count", 
                    sep="\t",col.names = c("gene_id","rep2"))
# merge data and delete the unuseful row
raw_count <- merge(merge(control, rep1, by="gene_id"), rep2, by="gene_id")
raw_count_filt <- raw_count[-1:-5,]

ENSEMBL <- gsub("(.*?)\\.\\d*?_\\d", "\\1", raw_count_filt$gene_id)
row.names(raw_count_filt) <- ENSEMBL


## the sample problem
delta_mean <- abs(mean(raw_count_filt$rep1) - mean(raw_count_filt$rep2))

sampleNum <- length(raw_count_filt$control)
sampleMean <- mean(raw_count_filt$control)
control2 <- integer(sampleNum)

for (i in 1:sampleNum){
  if(raw_count_filt$control[i] < sampleMean){
    control2[i] <- raw_count_filt$control[i] + abs(raw_count_filt$rep1[i] - raw_count_filt$rep2[i])
  }
  else{
    control2[i] <- raw_count_filt$control[i] + rpois(1,delta_mean)
  }
}

raw_count_filt$control2 <- control2

## differential expression analysis with DESeq2
library(DESeq2)
countData <- raw_count_filt[,2:5]
condition <- factor(c("control","KD","KD","control"))
dds <- DESeqDataSetFromMatrix(countData, DataFrame(condition), design= ~ condition )

dds <- DESeq(dds)

res <- results(dds)
summary(res)
mcols(res, use.names = TRUE)

plotMA(res, ylim = c(-5,5))
topGene <- rownames(res)[which.min(res$padj)]
with(res[topGene, ], {
  points(baseMean, log2FoldChange, col="dodgerblue", cex=2, lwd=2)
  text(baseMean, log2FoldChange, topGene, pos=2, col="dodgerblue")
})


res.shrink <- lfcShrink(dds, contrast = c("condition","KD","control"), res=res)
plotMA(res.shrink, ylim = c(-5,5))
topGene <- rownames(res)[which.min(res$padj)]
with(res[topGene, ], {
  points(baseMean, log2FoldChange, col="dodgerblue", cex=2, lwd=2)
  text(baseMean, log2FoldChange, topGene, pos=2, col="dodgerblue")
})

res.sig <- subset(res, padj < 0.05)


## differential expression analysis with edgeR
library(edgeR)
group <- factor(c("control","KD","KD","control"))
genelist <- DGEList(counts=raw_count_filt[,2:5], group = group)

###filter base on experience
keep <- rowSums(genelist$count) > 50
table(keep)
### or use CPM
keep <- rowSums(cpm(genelist) > 0.5 ) >=2
table(keep)
genelist.filted <- genelist[keep, ,keep.lib.sizes=FALSE]

### Normalization for composition bias
genelist.norm <- calcNormFactors(genelist.filted)
genelist.norm$samples

### design matrix
design <- model.matrix(~0+group)
colnames(design) <- levels(group)
design

### dispersion
genelist.Disp <- estimateDisp(genelist.norm, design, robust = TRUE)
plotBCV(genelist.Disp)
fit <- glmQLFit(genelist.Disp, design, robust=TRUE)
head(fit$coefficients)
plotQLDisp(fit)


## DGE analysis
cntr.vs.KD <- makeContrasts(control-KD, levels=design)
