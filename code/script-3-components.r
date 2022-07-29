# Author: Fabio Morea @ Area Science Park
# Package: Labour Market Network - version 1.0
# Description: R program to extract information from labour market data.
#               Original data is not included in the package as it contains persnoal information
#               Test data is random an contains no personal information

# SPDX-License-Identifier: CC-BY-4.0

# GitLab: https://gitlab.com/fabio-morea-areasciencepark/labour-market-network

# script 3: analysing netwoek components

## debug mode
debug <- FALSE
echo <- TRUE

## load libraries
library(tidyverse)
library(igraph)

## load graph
print("Loading data...")
g <- read_graph("./results/graph.csv", format="graphml")

windows();plot(g,
     layout=layout_with_mds,
     edge.color="gray",
     edge.size=1,
     edge.arrow.size = 0.5,
     vertex.color="black",
     vertex.size=2,
     vertex.label=NA)
 
  


## identify components
print("Analysing components...")
V(g)$comp<-components(g)$membership
table(components(g)$membership)
maxcomp<- which.max(table(components(g)$membership))

##plot giant component in red
print("Plotting full network in separate window...")
plot_title = "Full network g"
windows();plot(g,
             edge.color="gray",
             edge.arrow.size = 1,
             vertex.color= if_else ( V(g)$comp == maxcomp,"red","blue" ),
             vertex.label=NA,
             vertex.size=5, 
             layout=layout_with_mds)
title(main=plot_title,cex.main=1,col.main="black")


# plot only giant component
print("Plotting giant component in separate window...")
gg <- induced_subgraph(g, V(g)[ V(g)$comp == maxcomp ])

plot_title = "Giant ccomponent "
windows();plot(gg,
             edge.color="gray",
             edge.arrow.size = 0.2,
             vertex.color= if_else ( V(gg)$comp == maxcomp,"red","blue" ),
             vertex.label=NA,
             vertex.size=2, 
             layout=layout.fruchterman.reingold)
title(main=plot_title,cex.main=1,col.main="black")


print("Plotting other components in separate window...")
oc <- induced_subgraph(g, V(g)[ V(g)$comp != maxcomp ])
plot_title = "Other components "
windows();plot(oc,
             edge.color="gray",
             edge.arrow.size = 0.2,
             vertex.color= if_else ( V(gg)$comp != maxcomp,"red","blue" ),
             vertex.label=NA,
             vertex.size=3, 
             layout=layout.fruchterman.reingold)
title(main=plot_title,cex.main=1,col.main="black")



# saving
print("Saving giant component ...")
g %>% write_graph("./results/giant_component.csv", format="graphml")
as_long_data_frame(g) %>% write_csv("./results/giant_component_as_df.csv")

 print("Process completed, please check results folder.")

 