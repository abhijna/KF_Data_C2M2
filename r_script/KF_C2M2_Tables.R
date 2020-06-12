## Kids First and C2M2
---------------------------------------------------------------------------------------------------------------------------------------------------------
## This script was written by Abhijna Parigi on 06/05/2020 to make KF data tables (file.tsv, biosample.tsv, project.tsv and subject.tsv) for C2M2 input
## Some pre-processing: There are a few columns in the KF dataset that need to be changed. You will need to make these changes to the main datasets. 
## These columns are: File.Format, Data.type Anatomy. I've changed Experiment.Strategy programmatically.
## Refer to this GitHub issue to figure out what values go in there: https://github.com/dib-lab/cfde/issues/61
## The only post-processing is for biosample.tsv (read notes at the write.table command for biosample)
---------------------------------------------------------------------------------------------------------------------------------------------------------

## Importing packages here ##
  
require(tidyverse)
library(splitstackshape)

#### Importing KF data ####
## The required columns are spread across a couple of different datset, so import them all, 
## select columns you need and merge into on dataset
## I don't use kf3 for anything, but it's there now and I don't want to change all the variable names.
setwd("/Users/abhijnaparigi/Desktop/GitHub/KF_Data_C2M2/raw_data")

kf1 <- read.table(file = 'kf_data.tsv', sep = '\t', header = TRUE)
kf2 <- read.table(file = "kidsfirst-participant-family-manifest_2020-06-03.tsv", sep = '\t', header = TRUE)
kf3 <- read.table(file = "participant_clinical_20200608.tsv", sep = '\t', header = TRUE, fill = TRUE)
kf4 <- read.table(file = "participants_biospecimen_20200608.tsv", sep = '\t', header = TRUE)

## need to change some columns to character strings before we can join and do other data wrangling

kf1$Biospecimen.ID <- as.character(kf1$Biospecimen.ID)
kf1$Participants.ID <- as.character(kf1$Participants.ID)
kf1$Study.ID <- as.character(kf1$Study.ID)
kf1$File.Name <- as.character(kf1$File.Name)
kf1$File.Format <- as.character(kf1$File.Format)
kf1$Data.Type <- as.character(kf1$Data.Type)
kf1$Study.Name <- as.character(kf1$Study.Name)
kf2$Experiment.Strategy <- as.character(kf2$Experiment.Strategy)

## I only need the experimental.strategy column from kf2. Then combine the columns I want from the first two datasets

kf2_biosample <- kf2 %>% 
  select(Experiment.Strategy, File.ID)

kf <- left_join(kf1, kf2_biosample)

## Check to see if everything looks ok:
str(kf)
nrow(kf)
nrow(kf2)

## Make some empty column names. These need to be in there but don't necessarily need to be populated. 

kf$creation_time <- rep("", nrow(kf))
kf$persistent_id <- rep("", nrow(kf))
kf$sha256 <- rep("", nrow(kf))
kf$md5 <- rep("", nrow(kf))
kf$description <- rep("", nrow(kf))
kf$abbreviation <- rep("",nrow(kf))

## This value is the same for every cell of it'\s column.

kf$project_id_namespace <- rep("cfde_id_namespace:3", nrow(kf))
kf$id_namespace <- rep("cfde_id_namespace:3", nrow(kf))
kf$granularity <- rep("cfde_subject_granularity:0", nrow(kf))

## Take out all the missing data that looks like this "--"
## There are some repeated rows in the column called Study.ID and experimental strategy 
## but they are labelled differently. Ex. WGS, WGS. So I'm changing those to say it only once.
## Remember to change factors to characters or the conversion will get wonky.

kf1$Biospecimen.ID <- as.character(kf1$Biospecimen.ID)
kf$Participants.ID <- as.character(kf$Participants.ID)
kf$Study.ID <- as.character(kf$Study.ID)
kf$Experiment.Strategy <- as.character(kf$Experiment.Strategy)
kf$File.Name <- as.character(kf$File.Name)
kf$File.ID <- as.character(kf$File.ID)
kf$File.Format <- as.character(kf$File.Format)
kf$Data.Type <- as.character(kf$Data.Type)
kf$Study.Name <- as.character(kf$Study.Name)


kf <- kf %>%
  mutate_all(~ifelse(.=="--", NA, .)) %>%
  mutate(Study.ID = substr(Study.ID,1,11)) %>% 
  mutate(Experiment.Strategy = str_remove_all(Experiment.Strategy, ", WGS")) %>% 
  mutate(Experiment.Strategy = str_remove_all(Experiment.Strategy, ", WXS")) %>% 
  mutate(Experiment.Strategy = str_remove_all(Experiment.Strategy, ", RNA-Seq")) %>% 
  mutate(Experiment.Strategy = str_remove_all(Experiment.Strategy, ", Not Reported"))

## It's a bit harder to get rid of the extra biospecimen ids in a single cell, so this is a really crappy way of doing it.
## some are repeats and some are not, but we're going to keep the first one for now. i.e Biospecimen.ID_1. See in Biospample section below.

kf <- cSplit(kf, "Biospecimen.ID", ",")
kf <- cSplit(kf, "Study.Name", ",")
kf <- cSplit(kf, "Participants.ID") ## This is column that needs to be "gathered" because we care about all the values in each cell

head(kf)

## Gathering all the participant ids to make a long format.
## I'm not sure why some have 5 participant IDs! But let's not worry about that right now.

kf2 <- kf %>%
  gather("ColID", "Participants.ID", c("Participants.ID_1","Participants.ID_2","Participants.ID_3",
                              "Participants.ID_4","Participants.ID_5"),
         -(File.ID:Study.Name_5)) %>% 
  select(-ColID) ## take out this line if you want to see where the id came from. 
  

  
## change this part if you wish to select only first 100 for testing script

test_kf <- kf2 # kf[1:100,]
head(test_kf)

#### file.tsv ####

file_kf <- test_kf %>% 
  select(id_namespace, File.ID, project_id_namespace, Study.ID, persistent_id, 
         creation_time, File.Size, sha256, md5, File.Name, File.Format, Data.Type) %>% 
  rename (id = File.ID,
          project = Study.ID,
          size_in_bytes = File.Size,
          filename = File.Name,
          file_format = File.Format,
          data_type = Data.Type) %>% 
  distinct()

## Check to make sure file format and data type make sense
unique(file_kf$data_type)
unique(file_kf$file_format) # They do!

file_kf <- file_kf %>% 
  drop_na(id) %>% 
  drop_na(project)

file_kf <- as.data.frame(unclass(file_kf))
write.table(file_kf, file = "~/Desktop/file.tsv", row.names=FALSE, sep="\t", na="", quote = FALSE)

## Fixing last two columns:

unique(file_kf$file_format) ### These need to be replaced with the format number by searching for the terms here https://www.ebi.ac.uk/ols/search?q=Other&groupField=iri&start=0&ontology=edam
## e.g: instead of 'bam' use 'format:2572'
unique(file_kf$data_type) ## Add link for this here!


#### biosample.tsv #### 

biosample1 <- test_kf %>% 
  select(id_namespace, Biospecimen.ID_1, project_id_namespace, Study.ID, persistent_id, 
         creation_time, Experiment.Strategy) %>% 
  distinct()

## Bringing in info from kf4 now. Remember to change everything to character first

kf4$Biospecimens.Id <- as.character(kf4$Biospecimens.Id)
kf4$Composition <- as.character(kf4$Composition)

anatomy_col <- kf4 %>% 
  mutate_all(~ifelse(.=="--", NA, .)) %>%
  select(Biospecimens.Id, Composition)

anatomy_col <- rename(anatomy_col, Biospecimen.ID_1 = Biospecimens.Id)

## Must convert back to factor or character to join
biosample1$Biospecimen.ID_1 <- as.factor(biosample1$Biospecimen.ID_1)

biosample2 <- left_join(biosample1, anatomy_col)

biosample <- biosample2 %>% 
  rename(id = Biospecimen.ID_1,
         project = Study.ID,
         assay_type = Experiment.Strategy,
         anatomy = Composition) %>%
  distinct()


## Now change these out with ids from here:
unique(biosample$assay_type)

biosample$assay_type <- as.character(biosample$assay_type)
biosample <- biosample %>% 
  mutate_if(is.character, 
            str_replace_all, pattern = "WXS", replacement = "OBI:0002118") %>%
  mutate_if(is.character, 
            str_replace_all, pattern = "miRNA-Seq", replacement = "OBI:0001271") %>%
  mutate_if(is.character, 
            str_replace_all, pattern = "RNA-Seq", replacement = "OBI:0001271") %>%
  mutate_if(is.character, 
            str_replace_all, pattern = "Not Reported", replacement = "") %>% 
  mutate_if(is.character, 
            str_replace_all, pattern = "Linked-Read WGS", replacement = "OBI:0002117") %>% 
  mutate_if(is.character, 
            str_replace_all, pattern = "(10x Chromium)", replacement = "") %>% 
  mutate_if(is.character, 
            str_replace_all, pattern = "WGS", replacement = "OBI:0002117")

unique(biosample$assay_type)

# Sanity check
nrow(biosample)==length(unique(biosample$id)) ## FAILED! By about 100 rows. Probably due to unique combinations.

## Take out empty rows in id column
biosample <- biosample %>% 
  drop_na(id) %>% 
  drop_na(project)

## Change everything back to factor. If you don't there are "" around everything. And this breaks the model. Sigh
biosample <- as.data.frame(unclass(biosample))

## write the table
## Gotta take out parantheses from here: OBI:0002117 (). I can't figure out how to make R do it!
write.table(biosample, file = "~/Desktop/biosample.tsv", row.names=FALSE, sep="\t", na="", quote = FALSE)

#### subject.tsv #### 

subject <- test_kf %>% 
  select(id_namespace, Participants.ID, project_id_namespace, Study.ID, persistent_id, creation_time, granularity) %>% 
  distinct() %>% 
  rename (id = Participants.ID,
          project = Study.ID)
subject <- drop_na(subject, id)

# Sanity check
nrow(subject) == length(unique(subject$id))

subject <- as.data.frame(unclass(subject))
write.table(subject, file = "~/Desktop/subject.tsv", row.names=FALSE, sep="\t", na="", quote = FALSE)


#### project.tsv #### 

project <- test_kf %>% 
  select(id_namespace, Study.ID, persistent_id, creation_time, abbreviation, Study.Name_1, description) %>% 
  distinct() %>% 
  rename (id = Study.ID,
          name = Study.Name_1)

# Sanity check
nrow(project) == length(unique(project$id))

project <- na.omit(project)
project <- as.data.frame(unclass(project))

write.table(project, file = "~/Desktop/project.tsv", row.names=FALSE, sep="\t", na="", quote = FALSE)

