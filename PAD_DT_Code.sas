/*****************************************************************************/
/* NHANES PAD                                                                */
/*****************************************************************************/
/*  National Health and Nutrition Examination Survey (NHANES)                */       
/*  Peripheral Artery Disease (PAD)                                          */
/*  Data collection: household screener, interview, and physical examination */
/* OBJECTIVES: 														         */
/*  Understand the survey data and create a predictive model to identify the */
/*  main factors that are related to the disease. The model can also be      */
/*  useful to prioritize the physical exams and to support the diagnostics.  */
/* ACTIVITIES:                                                               */
/*  - Start the session                                                      */
/*  - Prepare the data for Modelling                                         */
/*  - Data Partition (Training and Validation)                               */
/*  - Feature Engineering (add additional features)                          */
/*  - Modelling - Decision Tree                                                             */
/*  - Scoring                                                                */
/*  - Assess                                                                 */ 
/*****************************************************************************/

/*****************************************************************************/
/*  Create a default CAS session and create SAS librefs for existing caslibs */
/*  so that they are visible in the SAS Studio Libraries tree.               */
/*****************************************************************************/ 
cas mySession sessopts=(timeout=1800 locale="en_US");
caslib _all_ assign;

/*****************************************************************************/
/* Prepare Data for Modeling - Create the target variable.                   */
/*****************************************************************************/
proc casutil;
  droptable casdata="NHANES_PAD1" incaslib="Public" quiet;
run;

data Public.NHANES_PAD1 promote; 
Set Public.NHANES_PAD;
	if LEXRABPI = . then LEXRABPI = LEXLABPI;
	if ((LEXLABPI < 0.9) OR (LEXRABPI< 0.9 )) then PAD_Target = 1;
		else PAD_Target = 0;
run;

/*****************************************************************************/
/* Partition the data into training and validation                           */
/*****************************************************************************/
proc partition data=PUBLIC.NHANES_PAD1 partition samppct=70 seed=1234;
  by PAD_Target;
  output out=PUBLIC.NHANES_PAD_PART copyvars=(_ALL_);
run;

/* Present the partitions on a bar chart */
ods graphics / reset width=6.4in height=4.8in imagemap;
title " Partition";
proc sgplot data=  PUBLIC.NHANES_PAD_PART ;
  vbar _PartInd_  / 
  group=PAD_Target groupdisplay=cluster datalabel ;
  yaxis grid ;
run;
ods graphics / reset;


/*****************************************************************************/
/* Feature Engineering                                                       */
/*****************************************************************************/
data PUBLIC.NHANES_PAD_PART(keep=PAD_Target _PartInd_ RIDAGEMN_Recode PulsePreassure 
                                  BMXBMI TC_HDL LBXGH Diabetes INDHHINC DMDEDUC2 
                                  RIDRETH1 DIQ150 DIQ110 SMQ040 ALQ100 RIAGENDR
                                  Hypertension);
set PUBLIC.NHANES_PAD_PART;
    PulsePreassure = BPXSAR - BPXDAR;
    TC_HDL = LBXTC / LBDHDL;
    IF ((DIQ010 In ('Yes','Borderline')) OR (DIQ050 In ('Yes')) OR (LBXGH > 6.5))
       then Diabetes = 1;
       else Diabetes = 0;
	IF ( BPXSAR >= 140 OR BPXDAR >= 90 ) 
       then Hypertension = 1; 
       else Hypertension = 0;
run;
/*
proc casutil outcaslib="Public";
  promote incaslib="Public" casdata="NHANES_PAD_PART";
run;
*/

/*****************************************************************************/
/* Model PAD_Target - Decision Tree                                          */
/*****************************************************************************/
ods title "Modelling";
ods noproctitle;
filename sfile filesrvc folderpath='/Users/sbreff/My Folder' 
	filename='Score_DT.sas';
filename tempfile temp;

proc treesplit data=PUBLIC.NHANES_PAD_PART;
	partition role=_PartInd_ (validate='0' train='1');
	input RIDAGEMN_Recode PulsePreassure BMXBMI TC_HDL LBXGH Diabetes 
         Hypertension / level=interval;
	input INDHHINC DMDEDUC2 RIDRETH1 DIQ150 DIQ110 SMQ040 ALQ100 
         RIAGENDR / level=nominal;
	target PAD_Target / level=nominal;
	prune none;
	autotune tuningparameters=(maxdepth numbin criterion) targetevent='1' 
		objective=misc maxtime=%sysevalf(60*60);
	ods output TunerResults=_tempTuneResults_;
	ods output EvaluationHistory=_tempEvalHistory_;
	ods output IterationHistory=_tempIterHistory_;
	ods output VariableImportance=work.Treesplit_varimp0001;
	code file=tempfile;
run;

%let x=%sysfunc(fcopy(tempfile, sfile));
%if &x %then %do;
%put &x - %sysfunc(sysmsg());
%end;
filename tempfile clear;
filename sfile clear;

/************************************************************************/
/* Score the data using the generated tree model score code             */
/************************************************************************/
data mycaslib._scored_tree;
 set PUBLIC.NHANES_PAD_PART;
  %include "/data/cas-landingzone/myPath/Score_DT.sas";
run;

/************************************************************************/
/* Assess                                                               */
/************************************************************************/
ods title "Assessment";
proc assess data=mycaslib._scored_tree nbins = 10   ncuts = 10 ;
   target PAD_Target / event="1" level=nominal;
   input  P_PAD_Target1 ;
          fitstat pvar=P_PAD_Target0 /
          pevent="0" delimiter=" ";
   ods output 
     ROCInfo=WORK._roc_temp LIFTInfo=WORK._lift_temp   ;
run;



/* Adjustments on the results tables */
data _null_;
   set WORK._roc_temp(obs=1);
   call symput('AUC',round(C,0.01));
run;

/* Add a row in lift information table for depth of 0.*/
data WORK._extraPoint;
   depth=0;
   CumResp=0;
run;   
data WORK._lift_temp;
    set WORK._extraPoint  WORK._lift_temp;
run;

/************************************************************************/
/* ROC and Lift Charts using validation data                            */
/************************************************************************/
proc sgplot data=WORK._roc_temp noautolegend aspect=1;
  title 'ROC Curve (Target = PAD_Target, Event = 1)';
  xaxis label='False positive rate' values=(0 to 1 by 0.1);
  yaxis label='True positive rate' values=(0 to 1 by 0.1);
  lineparm x=0 y=0 slope=1 / transparency=.7 LINEATTRS=(Pattern= 34);
  series  x=fpr y=sensitivity;
  inset "AUC=&AUC"/position = bottomright border;
run;

proc sgplot data=WORK._lift_temp noautolegend;
  title 'Lift Chart (Target = PAD_Target, Event = 1)';
  xaxis label='Population Percentage' ;
  yaxis label='Lift';
  series  x=depth y=lift;
run;

proc sgplot data=WORK._lift_temp noautolegend;
  title 'Cumulative Lift Chart (Target = PAD_Target, Event = 1)';
  xaxis label='Population Percentage' ;
  yaxis label='Lift';
  series  x=depth y=CumLift;
run;

proc sgplot data=WORK._lift_temp noautolegend  aspect=1;
  title 'Cumulative Response Rate (Target = PAD_Target, Event = 1)';
  xaxis label='Population Percentage' ;
  yaxis label='Response Percentage';
  series  x=depth y=CumResp;
  lineparm x=0 y=0 slope=1 / transparency=.7 LINEATTRS=(Pattern= 34);
run;

proc delete data= 
 WORK._extraPoint  WORK._lift_temp  WORK._roc_temp     ;
run;
