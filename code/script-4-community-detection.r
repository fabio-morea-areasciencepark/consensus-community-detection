# Author: Fabio Morea @ Area Science Park
# Package: Labour Market Network - version 1.0
# Description: R program to extract information from labour market data.
#               Original data is not included in the package as it contains personal information
#               Test data is contains no personal information

# SPDX-License-Identifier: CC-BY-4.0

# GitLab: https://gitlab.com/fabio-morea-areasciencepark/labour-market-network

# script 4: community detection

## clear terminal
shell("cls")

## debug mode
debug <- FALSE
echo <- TRUE

## load libraries
suppressPackageStartupMessages(library(tidyverse))
library(igraph)
library(glue)

source("./code/functions-network-analysis.R")

## load graph
print("Loading giant componente and making a graph...")
gc <- read_graph("./results/giant_component.csv", format="graphml")

if (debug){gc <- induced.subgraph(gc,which(V(gc)$core>3))}

# undirected graph to be used for algorithms that do not support directed
gc_undirected <- as.undirected(gc,mode = "collapse", edge.attr.comb = "sum")


## community detection using Edge Betweenneess algorithm *************************************************************
## https://www.rdocumentation.org/packages/igraph/versions/1.3.2/topics/cluster_edge_betweenness
print("Community detection using Edge Betweenneess algorithm...")

clusters_eb <- cluster_edge_betweenness(gc, 
                         weights = NA,
                         directed = TRUE,
                         edge.betweenness = TRUE,
                         merges = TRUE,
                         bridges = TRUE,
                         modularity = TRUE,
                         membership = TRUE)

# membership stored in igraph object
V(gc)$cl_eb <- membership(clusters_eb)
gc <- delete_vertex_attr(gc, "id")

# saving
if (echo){print("Saving edge betweenneess membership...")}
tibble(membership(clusters_eb)) %>% write_csv("./results/clusters_eb.csv")
describe_communities(gc, clusters_eb, "betweenness")
show_subgraphs (gc, clusters_membership=membership(clusters_eb), nrows=2, ncols=4, label = "betweenness" ) 
print("EB completed.")

## community detection using Eigenvector algorithm  *************************************************************
print("Community detection using Eigenvector algorithm...")

clusters_ev <- cluster_leading_eigen (gc_undirected, 
	steps = -1,
	weights = NA,
	start = membership(clusters_eb),
	options = arpack_defaults,
	callback = NULL,
	extra = NULL,
	env = parent.frame) 

# membership stored in igraph object
V(gc)$cl_ev <- membership(clusters_ev)

# saving
if (echo){print("Saving eigenvector membership...")}
tibble(membership(clusters_eb)) %>% write_csv("./results/clusters_ev.csv")
describe_communities(gc_undirected, clusters_ev, "eigenvector")
show_subgraphs (gc_undirected, clusters_membership=membership(clusters_ev), nrows=2,ncols=4, label = "eigenvector" ) 
print("EV completed.")

## community detection using Louvian algorithm  *************************************************************
print("Community detection using Louvian algorithm...")
clusters_lv <- cluster_louvain(gc_undirected,  resolution = 1)

# membership stored in igraph object
V(gc)$cl_lv <- membership(clusters_lv)

# saving
if (echo){print("Saving Louvian membership...")}
tibble(membership(clusters_lv)) %>% write_csv("./results/clusters_lv.csv")
describe_communities(gc_undirected, clusters_lv, "Louvian")
show_subgraphs (gc_undirected, clusters_membership=membership(clusters_lv), nrows=2,ncols=4, label = "Louvian" ) 
print("Louvian completed.")

## community detection using Leiden algorithm  *************************************************************
print("Community detection using Leiden algorithm...")

clusters_ld <- cluster_leiden(gc_undirected,  resolution = 1)
# membership stored in igraph object
V(gc)$cl_ld <- membership(clusters_ld)

# saving
print("Saving Leiden membership...")
tibble(membership(clusters_ld)) %>% write_csv("./results/clusters_ld.csv")
describe_communities(gc_undirected, clusters_ld, "Leiden")
show_subgraphs (gc_undirected, clusters_membership=membership(clusters_ld), nrows=2,ncols=4, label = "Leiden"  ) 
print("Leiden completed.")

## saving results *************************************************************************************************
if (echo){print("Saving giant component with 4 different clusters membership...")}
gc %>% write_graph("./results/gc_communities.csv", format="graphml")
as_long_data_frame(gc) %>% write_csv("./results/gc_communities_df.csv")

## comparing results of different methods *************************************************************************
print("Summary of communities by size")
cc <- community.size(clusters_eb, mm="betweenness") 
cc <- rbind(cc, community.size(clusters_ev, mm="eigenvector") )
cc <- rbind(cc, community.size(clusters_lv, mm="Louvian") )
cc <- rbind(cc, community.size(clusters_ld, mm="Leiden") )

non.trivial.communities <- cc %>% filter(c_sizes > 3)

figure<- ggplot(non.trivial.communities)+
geom_line(aes(x=i,y=c_sizes, group=method, col=method))+
geom_point(size=5, aes(x=i,y=c_sizes, group=method, col=method))+
theme_light()+theme(aspect.ratio=0.71)+
facet_grid(. ~ method )
windows();plot(figure)
ggsave (file="./results/figures/figure_comm_size.png", width=20, height=12, dpi=300)

## CONSENSUS
res=c(0.90,0.95,1.0,1.05,1.1) 
cl_louvian_200 <- cluster_N_times(g=gc_undirected, 
    res=res,
    n_trials=200, 
    min_cl_size = 2,
    clustering_algorithm="Louvian")  

as.data.frame(cl_louvian_200,
    row.names = NULL, 
    col.names = NULL) %>% 
    write_csv("./results/clusters_lv_200.csv", col_names=FALSE)

# inspect and compare the clustering results
# in this case compare all 200 trials and calculate the probability that each company is in the same cluster of any other company
# Then select as a cluster only those who have a probability > threshold 50%
all_clusters <- cl_louvian_200 ##DEBUG


ncompanies <- nrow(all_clusters)
N_trials   <- ncol(all_clusters)
x <- matrix(0, nrow=ncompanies, ncol=ncompanies)
for (i in (1:N_trials)){
  	nclusters <- max(all_clusters[,i])
	for (k in 1:nclusters) {
		samecluster <- (which(all_clusters[,i]==k))
		nc <- length(samecluster)
		for (t in 1:nc){
			for (j in 1:nc){ 
				x[samecluster[j],samecluster[t]] <- x[samecluster[j],samecluster[t]] +1
			}
      }
    }
}

x<-x/N_trials#normalize
print(mean(x))
windows();heatmap(x)
windows();hist(x[x>0.0])
colnames(x)<-V(gc)$name
rownames(x)<-V(gc)$name

threshold = .5			# threshold to decide on membership
ii=1 					# counts all clusters, including singletons
relevant_clusters = 0  	# counts only clusters with 3 or more members

consensus_clusters <- as_tibble_col(rownames(x))%>%
	mutate(membership=0)
more_clusers_to_be_found=TRUE

N_trials   <- ncol(all_clusters)

remaining_prob<-x

while (more_clusers_to_be_found){
  ii=ii+1
  cluster_ii_members <- which(remaining_prob[1,]>threshold)
  #print(cluster_ii_members)
  clust_prob<- remaining_prob[cluster_ii_members,cluster_ii_members]
  remaining_prob<- remaining_prob[-cluster_ii_members,-cluster_ii_members]

  if(length(cluster_ii_members)>=2) {
    relevant_clusters <- relevant_clusters +1
    consensus_clusters$membership[cluster_ii_members]<- relevant_clusters
    print(paste("Cluster ", relevant_clusters, " has ", length(cluster_ii_members), " members"))

  }
  print(paste("****>>>> nrow remaining prob ", nrow(remaining_prob)))
  	if ( nrow(remaining_prob)  > 3)  {
		more_clusers_to_be_found=TRUE
	} 
  	else{
		more_clusers_to_be_found=FALSE
	}

}

show_subgraphs (gc, clusters_membership=consensus_clusters$membership, nrows=2,ncols=3,label="Consensus Louvian" ) 

print("Script completed.")