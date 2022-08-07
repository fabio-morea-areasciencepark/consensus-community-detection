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
## load graph
print("Loading graph...")
g <- read_graph("./results/graph.csv", format="graphml")
g <- induced.subgraph(g, V(g)[ CL0 == 1])#giant component
if (debug){
    g <- induced.subgraph(g,which(V(g)$core>3))
    print("Debug mode")
    }
# undirected graph to be used for algorithms that do not support directed
g_undirected <- as.undirected(g,mode = "each")

## TODO at this stage we do community detection on giant componennt, 
## but this overlooks a relevant opportunity: communities are level-1 clusters
## and we should do hiearchical clustering



## community detection using Edge Betweenneess algorithm *************************************************************
## https://www.rdocumentation.org/packages/igraph/versions/1.3.2/topics/cluster_edge_betweenness
print("Community detection using Edge Betweenneess algorithm...")

clusters_eb <- cluster_edge_betweenness(g, 
                         weights = NA,
                         directed = TRUE,
                         edge.betweenness = TRUE,
                         merges = TRUE,
                         bridges = TRUE,
                         modularity = TRUE,
                         membership = TRUE)

# membership stored in igraph object
V(g)$cl_eb <- membership(clusters_eb)
g <- delete_vertex_attr(g, "id")

# saving
if (echo){print("Saving edge betweenneess membership...")}
tibble(membership(clusters_eb)) %>% write_csv("./results/clusters_eb.csv")
describe_communities(g, clusters_eb, "betweenness")
show_subgraphs (g, clusters_membership=membership(clusters_eb), nrows=2, ncols=4, label = "betweenness" ) 
print("EB completed.")

## community detection using Eigenvector algorithm  *************************************************************
print("Community detection using Eigenvector algorithm...")

clusters_ev <- cluster_leading_eigen (g_undirected, 
	steps = -1,
	weights = NA,
	#start = V(g)$cl_eb,
	options = arpack_defaults,
	callback = NULL,
	extra = NULL,
	env = parent.frame) 

# membership stored in igraph object
V(g)$cl_ev <- membership(clusters_ev)

# saving
if (echo){print("Saving eigenvector membership...")}
tibble(membership(clusters_eb)) %>% write_csv("./results/clusters_ev.csv")
describe_communities(g_undirected, clusters_ev, "eigenvector")
show_subgraphs (g_undirected, clusters_membership=membership(clusters_ev), nrows=2,ncols=4, label = "eigenvector" ) 
print("EV completed.")

## community detection using Louvian algorithm  *************************************************************
print("Community detection using Louvian algorithm...")
clusters_lv <- cluster_louvain(g_undirected,  resolution = 1)

# membership stored in igraph object
V(g)$cl_lv <- membership(clusters_lv)

# saving
if (echo){print("Saving Louvian membership...")}
tibble(membership(clusters_lv)) %>% write_csv("./results/clusters_lv.csv")
describe_communities(g_undirected, clusters_lv, "Louvian")
show_subgraphs (g_undirected, clusters_membership=membership(clusters_lv), nrows=2,ncols=4, label = "Louvian" ) 
print("Louvian completed.")

## community detection using Leiden algorithm  *************************************************************
print("Community detection using Leiden algorithm...")

clusters_ld <- cluster_leiden(g_undirected,  resolution = 1)
# membership stored in igraph object
V(g)$cl_ld <- membership(clusters_ld)

# saving
print("Saving Leiden membership...")
tibble(membership(clusters_ld)) %>% write_csv("./results/clusters_ld.csv")
describe_communities(g_undirected, clusters_ld, "Leiden")
show_subgraphs (g_undirected, clusters_membership=membership(clusters_ld), nrows=2,ncols=4, label = "Leiden"  ) 
print("Leiden completed.")

## saving results *************************************************************************************************
if (echo){print("Saving giant component with 4 different clusters membership...")}
g %>% write_graph("./results/communities.csv", format="graphml")
as_long_data_frame(g) %>% write_csv("./results/communities_df.csv")

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

#sorted_nodes <- order(V(g)$cl_ev)
#print(sorted_nodes)
#heatmap(x,Rowv = sorted_nodes, Colv = sorted_nodes)

print("Script completed.")