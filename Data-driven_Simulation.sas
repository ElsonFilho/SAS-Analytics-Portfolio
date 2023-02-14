/*******************************************************************/
/* Rick Wicklin - Data-driven Simulation                           */
/*******************************************************************/
/* Level II - Simple MoC data for demos and tests.                  */
/*           Based on random numbers.                              */
/* Examples from Rick's Blog on Do-Loop                            */
/*                                                                 */
/* November 2022                                                   */
/* Elson Mendes Filho - elson.filho@sas.com                        */
/*******************************************************************/

/*******************************************************************/
/* Data-driven Simulation  
https://blogs.sas.com/content/iml/2017/09/27/data-driven-simulation.html

/* PROC MEANS generates the Mean and StdDev for the real data and writes
 values to a data set (params) by groups (class Species).  */
proc means data=sashelp.iris N Mean StdDev stackods;
   class Species;
   var PetalLength;
   ods output Summary=params;
run;

/* Simulated the data */
data Sim_iris;
call streaminit(12345);
set params;                      /* implicit loop over groups k=1,2,... */
do i = 1 to N;                   /* simulate N[k] observations */
   PetalLength = rand("Normal", Mean, StdDev); /* from k_th normal distribution */
   output;
end;
run;

/* Generate charts */
proc sgplot data=sashelp.iris;
    title height=14pt "Original Iris";
	histogram PetalLength / group=Species transparency=0.5;
	density PetalLength / type=normal group=Species;
	yaxis grid;
run;

proc sgplot data=Sim_iris;
    title height=14pt "Simulated Iris";
	histogram PetalLength / group=Species transparency=0.5;
	density PetalLength / type=normal group=Species;
	yaxis grid;
run;

/*******************************************************************/


/*******************************************************************/
/* Simulate multivariate normal data in SAS by using PROC SIMNORMAL
https://blogs.sas.com/content/iml/2017/09/25/simulate-multivariate-normal-data-sas-simnormal.html

Use the SIMNORMAL proc to simulate data from a multivariate normal
distribution. It can read a TYPE=CORR or TYPE=COV data set. 
Usually, these special data sets are created as an output data set
from another procedure. */

/* Get the correlations */
proc corr data=sashelp.iris(where=(Species="Versicolor"))  /* input raw data */
          nomiss noprint outp=OutCorr;                     /* output statistics */
var PetalLength PetalWidth SepalLength SepalWidth;
run;
proc print data=OutCorr; run;

/* PROC SIMNORMAL simulates 50 observations from a multivariate normal population. */
proc simnormal data=OutCorr outsim=SimMVN
               numreal = 50           /* number of realizations = size of sample */
               seed = 12345;          /* random number seed */
   var PetalLength PetalWidth SepalLength SepalWidth;
run;
 
/* combine the original data and the simulated data */
data Both;
set sashelp.iris(where=(Species="Versicolor")) /* original */
    SimMVN(in=sim);                            /* simulated */
Simulated = sim;
run;
 
ods graphics / attrpriority=none;   /* use different markers for each group */
title "Overlay of Original and Simulated MVN Data";
proc sgscatter data=Both;
   matrix PetalLength PetalWidth SepalLength SepalWidth / group=Simulated;
run;
ods graphics / attrpriority=none;   /* reset markers */

/*******************************************************************/


/*******************************************************************/
/* Simulate multivariate correlated data by using PROC COPULA in SAS  
https://blogs.sas.com/content/iml/2021/07/07/proc-copula-sas.html

This example shows how to use PROC COPULA to simulate data that has a 
specified rank correlation structure.

Suppose you want to simulate data that have marginal distributions and 
correlations that are similar to the joint distribution of the MPG_City, 
Weight, and EngineSize variables in the Sashelp.Cars data set. 
*/

/* for ease of discussion, rename vars to X1, X2, X3 */
data Have;
set Sashelp.Cars(keep= MPG_City Weight EngineSize);
label MPG_City= Weight= EngineSize=;
rename MPG_City=X1 Weight=X2 EngineSize=X3;
run;
 
/* graph original (renamed) data */
ods graphics / width=500px height=500px;
proc corr data=Have Spearman noprob plots=matrix(hist);
   var X1 X2 X3;
   ods select SpearmanCorr MatrixPlot;
run;

/* Simulate from the copula */
%let N = 428;            /* sample size */
proc copula data=Have;
   var X1 X2 X3;         /* original data vars */
   fit normal;           /* choose normal copula; estimate covariance by MLE */
   simulate / seed=1234 ndraws=&N
              marginals=empirical    /* transform from copula by using empirical CDF of data */
              out=SimData            /* contains the simulated data */
              plots=(datatype=both); /* optional: scatter plots of copula and simulated data */
              /* optional: use OUTUNIFORM= option to store the copula */
   ods select SpearmanCorrelation MatrixPlotSOrig MatrixPlotSUnif;
run;

/* you can run a Monte Carlo simulation from the simulated data */
%let NumSamples = 100; /* = B = number of Monte Carlo simulations */
%let NTotal = %eval(&N * &NumSamples);
%put &=NTotal;
 
ods exclude all;
proc copula data=Have;
   var X1 X2 X3;
   fit normal;
   simulate / seed=1234 ndraws=&NTotal marginals=empirical out=SimData;
run;
ods exclude none;
 
/* add ID variable that identifies each set of &N observations */
data MCData;
set SimData;
SampleID = ceil(_N_/&N);  /* 1,1,...,1,2,2,....,2,3,3,... */
run;

/* graph the simulated MCdata */
ods graphics / width=500px height=500px;
proc corr data=MCData Spearman noprob plots=matrix(hist) PLOTS(MAXPOINTS=none);
   var X1 X2 X3;
   ods select SpearmanCorr MatrixPlot;
run;


