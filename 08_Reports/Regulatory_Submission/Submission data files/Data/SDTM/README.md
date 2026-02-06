# SAS-Clinical-Trials-Toolset

SAS scripts for clinical trials applications including generating SDTM domains, ADaM datasets, and Define.xml files.

Important: The data and programs in this toolset were derived from Holland and Shostak (2012). However, extensive modifications were made
throughout the data and programs. All the programs are fully tested and correctly functional under SAS University Edition and Windows 10 OS.


## Workflow in practice

1) Create metadata specs (typically in Excel, annotated CRFs, or metadata repository). 

2) (After locking data) Example: for SDTM, you specify DM, AE, LB, etc. with variable names, labels, types, lengths, origins.

3) For ADaM, you define derived variables, derivation methods, and analysis population flags.

4) Program SAS datasets according to the specs.

5) Generate Define.xml (metadata file) from your specs using Pinnacle 21 Community or commercial metadata tools.

6) Run Pinnacle 21 validation → check that datasets align with metadata.


### 1. Preprocess programs (read in data)

a) "common.sas": common library settings

b) "dm.sas": reads in "dm.csv" to process raw demographic data; wide format 

c) "ae.sas": reads in "ae.xlsx" to process raw adverse event data

d) "ds.sas": reads in "ds.xlsx" to process raw dosing data

e) "pn.sas": reads in "pn.dat" to process raw pain score data

f) "lab.sas": reads in "lab.xls" to process raw labs data


### 2. Metadata

Metadata comes first. You design the metadata up front (usually in Excel, Define-XML, or a metadata repository).That metadata acts as the specification/reference for your SAS programmers to create datasets.
This metadata can be created manually, such as in a lab notebook or text file, or by using specialized software, like a clinical metadata repository (CMDR).
While not exactly the same thing, metadata is an integral part of data specifications in a clinical trial. The data specification defines the requirements for data collection, management, and submission. 
Metadata provides the necessary descriptive information that gives context and meaning to the collected data. fda require metadata, specifications are used internal. 


### 3. "Define.xml" program
("make_define.sas": contains a macro "%make_define" to generate parts of the define.xml file for the SDTM and ADaM, which can be further concatenated into the define.xml file.)

Once datasets are ready, you export Define.xml from your metadata source (Excel → Pinnacle 21 → Define.xml).

This Define.xml is the official metadata file that reviewers (FDA, PMDA, etc.) will use.

This is the machine-readable file (XML format) that contains all your submission metadata. both need to be submitted . 
sdtm define include datasets, variables, values, and compute methods, and control terminology, and external dictionaries.  
adam define include tables, datasets, variables, values,   and code list, and external dictionaries.  

Scope: Controlled Terminology is broader and often standard-based, while a Value List (Codelist) is specific to a variable within a particular study.
SDTM Value Lists: Represent the collected, raw data values, often adhering to CDISC Controlled Terminology where applicable. ADaM Code Lists: Represent analysis-specific codes, often derived or transformed from SDTM values, to facilitate statistical analysis and reporting.


### 4. SDTM programs

a) "make_empty_dataset.sas": contains a macro "%make_empty_dataset" to generate an empty domain dataset according to the variable list specified in the metadata file "SDTM_METADATA.xlsx".

b) "make_sdtm_dy2.sas": contains a macro "%make_sdtm_dy2" to generate study day for date variables.

c) "make_sort_order.sas": contains a macro "%make_sort_order" to generate a macro variable which contains the keys for ranking a SDTM dataset.

d) "sdtm_dm.sas": generates the SDTM DM and SUPPDM domain datasets from "dm.sas" and "ds.sas" outputs.  dm+empty+dosing   

e) "sdtm_ae.sas": generates the SDTM AE domain dataset from "sdtm_dm.sas" and "ae.sas" outputs. ae+empty+dm 

f) "sdtm_EX.sas": generates the SDTM EX domain dataset from "sdtm_dm.sas" and "ds.sas" outputs. ex + empty+dosing+ dm 

g) "sdtm_lb.sas": generates the SDTM LB domain dataset from "sdtm_dm.sas" and "lb.sas" outputs. lb+empty+dm

h) "sdtm_xp.sas": generates the SDTM XP domain dataset from "sdtm_dm.sas" and "pn.sas" outputs. xp+empty+dm


### 5. ADaM programs

a) "setup.sas": contains library and format settings. 

b) "cfb.sas": contains a macro "%cfb" to generate baseline values and change from the baseline.

c) "dtc2dt.sas": contains a macro "%dtc2dt" to convert character date to numeric date.

d) "mergesupp.sas": contains a macro "%mergesupp" to merge supplemental qualifiers into the parent SDTM domain.

e) "adam_adsl.sas": generates the ADaM ADSL domain dataset from "sdtm_dm.sas" and "sdtm_xp.sas" outputs.  dm+suppdm+xp, change+ empty 

f) "adam_adae.sas": generates the ADaM ADAE domain dataset from "adam_adsl.sas" and "sdtm_ae.sas" outputs. adsl+ae+ empty

g) "adam_adef.sas": generates the ADaM ADEF domain dataset from "adam_adsl.sas" and "sdtm_xp.sas" outputs. xp+adsl+empty,  do not consider time

h) "adam_adtte.sas": generates the ADaM ADTTE domain dataset from "adam_adsl.sas", "adam_adae.sas" and "adam_adef.sas" outputs. adsl+adef+adae+  ex+ empty  , consider time


Each study will have at least one ADSL (Subject-Level Analysis Dataset) and can have several BDS datasets, depending on the complexity and analytical needs of the study.  In oncology, a study might have multiple BDS datasets, such as ADTR (Tumour Assessment), ADRS (Response), ADEFFSUM (Efficacy Summary), and ADTTE (Time-to-Event), to analyze different aspects of efficacy data. For example, a study that requires analysis of adverse events and concomitant medications would have at least two OCCDS datasets: ADAE and ADCM. Other studies could have more or fewer, depending on their design. 


- Notice differences from SDTM:

ADaM includes analysis-ready variables (e.g., treatment dates, flags, age groups).

Many variables are derived using rules defined in the Statistical Analysis Plan (SAP).

SDTM metadata is about capturing CRF/collected data.

ADaM metadata is about defining derived/analysis-ready data.

Both sdtm and adam are Long format by default.

Both must be designed first in metadata, then programmed in SAS, then documented in Define.xml, then validated.


### 6. Validate with Pinnacle 21

- You load both datasets + Define.xml into Pinnacle 21.

- Pinnacle 21 checks:

Does DM have all the variables required by SDTM IG?

Do labels and variable names match Define.xml?

Are values within controlled terminology (e.g., SEX = M/F only)?

Are lengths/types consistent?


### 7. TLF

Population definitions:

- ITT population after randomization. 
- Safety population is for those at least one dose.
- Efficacy population is for those at least one dose and one assessment. 
- Complete population  Excludes early discontinuations/dropouts


- Tables:
study implement tables+ demographic+ efficacy + dose + adverse + sae + lab+ vital signs + pk/pd

- Figure:

Study disposition (CONSORT flow)

Efficacy (KM plots, forest plots, waterfall/swimmer plots, longitudinal changes)

Safety (AE bar charts, lab shift plots, vital sign trends)

PK/PD (if relevant)

- Listings (all subject-level data outputs):

Disposition/Demographics

Efficacy endpoints (per subject)

Safety (AEs, labs, meds, deaths, etc.)

Exposure & compliance

PK/PD (if applicable)


