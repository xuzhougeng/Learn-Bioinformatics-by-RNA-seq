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

res <- results(dds, contrast = c("condition","control","KD"))
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

sig.deseq2 <- subset(res, padj < 0.05)


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
summary(genelist.Disp$common.dispersion)
summary(genelist.Disp$trended.dispersion)
summary(genelist.Disp$tagwise.dispersion)

plotBCV(genelist.Disp)
fit <- glmQLFit(genelist.Disp, design, robust=TRUE)
head(fit$coefficients)
plotQLDisp(fit)


## DGE analysis
cntr.vs.KD <- makeContrasts(control-KD, levels=design)
res <- glmQLFTest(fit, contrast=cntr.vs.KD)
topTags(res,n=10)
is.de <- decideTestsDGE(res)
summary(is.de)
plotMD(res, status=is.de, values=c(1,-1), col=c("red","blue"),
       legend="topright")

tr <- glmTreat(fit, contrast=cntr.vs.KD, lfc=log2(1.5))
topTags(tr)
is.de <- decideTestsDGE(tr)
summary(is.de)
plotMD(tr, status=is.de, values=c(1,-1), col=c("red","blue"),
       legend="topright")

sig.edger <- res$table[p.adjust(res$table$PValue, method = "BH") < 0.01, ]


## differential expression analysis with LIMMA
library(edgeR)
library(limma)
group <- factor(c("control","KD","KD","control"))
genelist <- DGEList(counts=raw_count_filt[,2:5], group = group)

###filter base  use CPM
keep <- rowSums(cpm(genelist) > 0.5 ) >=2
table(keep)
genelist.filted <- genelist[keep, ,keep.lib.sizes=FALSE]

### normalization
genelist.norm <- calcNormFactors(genelist.filted, method = "TMM")


### DGE with limma-trend
design <- model.matrix(~0+group)
colnames(design) <- levels(group)
logCPM <- cpm(genelist.norm, log=TRUE, prior.count=3)
fit <- lmFit(logCPM, design)
fit <- eBayes(fit, trend=TRUE)
topTable(fit, coef=ncol(design))

### DGE with voom
v <- voom(genelist.norm, design, plot=TRUE)
#v <- voom(counts, design, plot=TRUE)
fit <- lmFit(v, design)
fit <- eBayes(fit)
all <- topTable(fit, coef=ncol(design), number=10000)

sig.limma <- all[all$adj.P.Val < 0.01, ]

fit <- treat(fit, lfc=log2(1.2))
topTreat(fit, coef=ncol(design))
all <- topTreat(fit, coef=ncol(design), number=10000)
sig.limma <- all[all$adj.P.Val < 0.01, ]

## difference between different packages
library(UpSetR)
input <- fromList(list(edgeR=rownames(sig.edger), DESeq2=rownames(sig.deseq2), limma=rownames(sig.limma)))



## enrichment analysis
BiocInstaller::biocLite("clusterProfiler")
library(clusterProfiler)
library(AnnotationHub)
ah <- AnnotationHub()
query(ah, 'org.HS.eg.db')
org.hs <- ah[['AH53766']]

deseq2.sig <- subset(res, padj < 0.05 & abs(log2FoldChange) > 1)
dim(deseq2.sig)
?enrichGO

ego <- enrichGO(
  gene = row.names(deseq2.sig),
  OrgDb = org.hs,
  keytype = "ENSEMBL",
  ont = "MF"
)
dotplot(ego,font.size=5)
enrichMap(ego, vertex.label.cex=1.2, layout=igraph::layout.kamada.kawai)
cnetplot(ego, foldChange=deseq2.sig$log2FoldChange)
plotGOgraph(ego)


### GSEA
genelist <- sig.deseq2$log2FoldChange
names(genelist) <- rownames(sig.deseq2)
genelist <- sort(genelist, decreasing = TRUE)
gsemf <- gseGO(genelist, 
      OrgDb = org.hs,
      keyType = "ENSEMBL",
      ont="MF"
      )
head(gsemf)

gseaplot(gsemf, geneSetID="GO:0004871")

### KEGG enrichment 
library(clusterProfiler)
gene_list <- mapIds(org.hs, keys = row.names(deseq2.sig),
                       column = "ENTREZID", keytype = "ENSEMBL" )

kk <- enrichKEGG(gene_list, organism="hsa", 
                 keyType = "ncbi-geneid",
                 pvalueCutoff=0.05, pAdjustMethod="BH", 
                 qvalueCutoff=0.1)
head(summary(kk))

dotplot(kk)
