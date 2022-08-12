# Author: Fabio Morea @ Area Science Park
# Acknowledgments: this research work is supervided by prof. Domenico De Stefano, within the frame of PhD in Applied Data Science and Artificial Intelligence @ University of Trieste

# Package: Labour Market Network - version 1.0
# Description: R program to extract information from labour market data.
#               Original data is not included in the package as it contains personal information
#               Test data is contains no personal information

# SPDX-License-Identifier: CC-BY-4.0

# GitLab: https://gitlab.com/fabio-morea-areasciencepark/labour-market-network

# script 6: compare results of community detection
# the basic idea is that clusters should be more homogeneous than the whole network

## clear terminal
shell("cls")

## debug mode
debug <- FALSE
echo <- FALSE

## load libraries
suppressPackageStartupMessages(library(tidyverse))
library(igraph)
library(glue)
library(tidyverse)
library(readxl)
library(ggpubr)
library(gridExtra)
library(png)
library(grid)



source("./code/functions-cluster-attributes.R")

## load graph
print("Loading graph...")
g <- read_graph("./results/communities_consensus.csv", format="graphml")
g <- induced.subgraph(g, V(g)[ CL0 == 1])
if (debug){
    g <- induced.subgraph(g,which(V(g)$core>3))
    print("Debug mode")
    }

clusters <- 
    as.data.frame(table(V(g)$CL1 )) %>%
    rename(name = Var1)%>%
    rename(size = Freq)

orgs <- read_csv("./tmp/organisations.csv")
reference_pg  <- get.professional.groups(g, cluster_name="reference_pg")
reference_loc <- get.locations(g, cluster_name="reference_loc")
reference_nace<- get.nace(g, cluster_name="reference_nace")


plot_list <- list()
clusters_to_process <- unname((clusters$name))
if (debug){clusters_to_process <- clusters_to_process[1:4]}

for (i in clusters_to_process){
  gi <- induced.subgraph(g, V(g)[ V(g)$CL1 == i ])
  cl_size <- length(V(gi)$name)

  if (cl_size>3){
      print(paste("processing cluster",i, "  size", cl_size))
      
      additional_info <- orgs %>%
        filter(CF %in% V(gi)$name) %>%
        select(CF, az_ragione_soc,sede_op_comune ,sede_op_ateco)%>%
        mutate(sector = substring(sede_op_ateco,1,2))%>%select(-sede_op_ateco)
      print(additional_info)

      orgs_in_community <- tibble(CF = V(g)$name, core = V(g)$core, str=V(g)$str)%>%
        filter(CF %in% V(gi)$name)%>%
        merge(additional_info,by="CF")
      
      row1 <- ggplot() +  theme_void() +
            annotate("text", x = 0, y = 10, label = "")+ 
            annotate("text", x = 0, y = 4, label = paste("Community ", i) , 
                      color="black", size=10 , angle=0, fontface="bold")+ 
            annotate("text", x = 0, y = 2, label = paste("Size ", cl_size) , 
                      color="black", size=8 , angle=0, fontface="italic")
           

# row 2 network ---------------------------------------------------------
      figname <- paste0("./tmp/commpnity",i,".png")
      png(figname, 600, 600)
      plot(gi, 
        edge.color="gray",
        edge.width=E(gi)$weight*2,
        edge.arrow.size= E(gi)$weight*4,
        vertex.color=factor(V(gi)$core),
        vertex.label=NA,
        vertex.size=V(gi)$core,
        layout=layout_with_kk) 
      dev.off()
      graph <- rasterGrob(png::readPNG(figname) )

      p2 <- scatter_strength_core(g,gi)

            
      row2 <- ggarrange(p2,graph, ncol = 2, labels = c(" ", "community"))

# row 3 professional groups ------------------------------------------------
      current_pg <- get.professional.groups(gi, cluster_name="current_pg")
      data <- bind_rows(current_pg,reference_pg)

      data<-data%>%
        select(-Freq)%>%
        pivot_wider(names_from=cl_name , values_from = rel_freq) %>%
        mutate(current_pg = if_else(is.na(current_pg), 0, current_pg))%>%
        mutate(variation = ( current_pg/reference_pg) )%>%
        arrange(variation)

      p3 <- ggplot(data) + theme_light() + 
            geom_col(aes(x=prof_groups,y=variation)) + 
            geom_hline(yintercept=1.0, color = "green") +
            xlim(reference_pg$prof_groups) + ylim(0,3) 

      top_names <- orgs_in_community%>%
        select(CF,az_ragione_soc, core, str)%>%
        arrange(-str) %>%
        filter(core > 2) %>%   
        distinct(CF,.keep_all = TRUE) %>%  
        head(20)
     
      legend3 <- ggplot() +  theme_void() +
            annotation_custom(tableGrob(top_names))

      row3<- ggarrange(legend3,p3)

# row 4 locations --------------------------------------------------
      current_loc <- get.professional.groups(gi, cluster_name="current_loc")
      data <- bind_rows(current_loc,reference_loc)
      data<-data%>%
        select(-Freq)%>%
        pivot_wider(names_from=cl_name , values_from = rel_freq) %>%
        mutate(current_loc = if_else(is.na(current_loc), 0, current_loc))%>%
        mutate(variation = ( current_loc/reference_loc) )%>%
        arrange(variation)
      
      p4 <- ggplot(data) + theme_light() + 
            geom_col(aes(x=LOC,y=variation)) + 
            geom_hline(yintercept=1.0, color = "green") +
            xlim(reference_pg$prof_groups) + ylim(0,3) 

      top_locs <- orgs_in_community%>%
        select(LOC, sede_op_comune) %>% tally()%>%  head(20)
      print(top_locs)
      legend4 <- ggplot() +  theme_void() +
            annotation_custom(tableGrob(top_locs))



      row4<- ggarrange(legend4,p4)

# row 5 sectors --------------------------------------------------
      top_NACE <- orgs_in_community%>%
        select(NACE, sede_op_ateco) %>% tally()%>%  head(20)
      print(top_NACE)
      legend5 <- ggplot() +  theme_void() +
            annotation_custom(tableGrob(top_NACE))
      p5 <- ggplot(data) + theme_light() + 
            geom_col(aes(x=NACE,y=variation)) + 
            geom_hline(yintercept=1.0, color = "green") +
            xlim(reference_pg$prof_groups) + ylim(0,3) 

      row5<- ggarrange(legend5,p5)

# page --------------------------------------------------
      print(paste("adding to plot list ", i ))
      plot_list[[i]] <- ggarrange(row1, row2,row3, row4,row5,   nrow = 5 )
  }
}

#all plots in the same png file
# plot_grob <- arrangeGrob(grobs=plot_list)
# png("./results/figures/comm_variation_prof_group.png")
# grid.arrange(plot_grob)
# dev.off()

#all plots in a pdf, one for each page
ggsave(filename = "./results/figures/comm_variation_prof_group.pdf", 
   plot = marrangeGrob(plot_list, nrow=1, ncol=1), 
   width = 19, height = 29)

print("Script completed.")
