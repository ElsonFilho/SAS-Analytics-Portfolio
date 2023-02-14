/*****************************************************************************/
/*  Example SAS Code to get started with SAS Viya                            */
/*                                                                           */
/*  Elson Mendes Filho - SAS Switzerland - elson.filho@sas.com               */
/*****************************************************************************/

/*****************************************************************************/
/* THIS PIECE IS AVAILABLE ON THE LEFT SIDE MENU SNINIPETS:                  */
/*   SAS Snippets/SAS Viya Cloud Analytics Services/New CAS Session          */
/*****************************************************************************/
/*  Start a session named mySession using the existing CAS server connection */
/*  while allowing override of caslib, timeout (in seconds), and locale      */
/*  defaults.                                                                */
/*****************************************************************************/
cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");

/*****************************************************************************/
/* THIS PIECE IS AVAILABLE ON THE LEFT SIDE MENU SNINIPETS:                  */
/*   SAS Snippets/SAS Viya Cloud A. S. /Generate SAS librefs for caslibs     */
/*****************************************************************************/
/*  Create a default CAS session and create SAS librefs for existing caslibs */
/*  so that they are visible in the SAS Studio Libraries tree.               */
/*****************************************************************************/
caslib _all_ assign;

/*****************************************************************************/
/* THIS PIECE IS AVAILABLE ON THE LEFT SIDE MENU SNINIPETS:                  */
/*   SAS Snippets/SAS Viya Cloud Analytics Services/New caslib for Path      */
/*****************************************************************************/
/*  Create a CAS library (myCaslib) for the specified path ("/filePath/")    */
/*  and session (mySession).  If "sessref=" is omitted, the caslib is        */
/*  created and activated for the current session.  Setting subdirs extends  */
/*  the scope of myCaslib to subdirectories of "/filePath".                  */
/*****************************************************************************/
caslib myCaslib datasource=(srctype="path") path="/data/cas-landingzone/myPath"
sessref=mySession subdirs;
libname myCaslib cas;


/*****************************************************************************/
/* THIS PIECE IS AVAILABLE ON THE LEFT SIDE MENU SNINIPETS:                  */
/*   SAS Snippets/SAS Viya Cloud Analytics Services/Load Data to caslib      */
/* This snippet presents different options, I selected This one:             */
/*****************************************************************************/
/*  Load SAS data set from a Base engine library (library.tableName) into    */
/*  the specified caslib ("myCaslib") and save as "targetTableName".         */
/*****************************************************************************/
proc casutil;
    droptable casdata="IRIS" incaslib="myCaslib" quiet;
	load data=SASHELP.IRIS outcaslib="myCaslib" casout="Iris";
run;

/*****************************************************************************/
/*  Load SAS data set from a Base engine library into the "myCaslib")        */
/*  using SAS DATA step.                                                     */
/*****************************************************************************/
data myCaslib.cars;
 set SASHELP.CARS;
run; 

/*****************************************************************************/
/* Load a dataset in the global caslib "Public" using CASUTIL.               */
/* the PROMOTE option makes the tables scope global.                         */
/*****************************************************************************/
PROC CASUTIL;
    droptable casdata="AIR" incaslib="Public" quiet;
	load data=SASHELP.AIR outcaslib="Public" casout="AIR" promote;
QUIT;


/******************************************************************************/
/* IMPORT DATA                                                                */
/******************************************************************************/
/* UPLOAD THE FILE using the "Upload Files" buttom on Explorer to a folder    */
/* where you are alowed to include files and caslib.                          */
/******************************************************************************/
/* LOAD A CSV FILE using proc casutil.                                        */
proc casutil;  
   droptable casdata="DataSetA" incaslib="myCaslib" quiet;                                     
   load file='/data/cas-landingzone/myPath/DatasetA_csv.csv'         
      importoptions = (filetype="CSV" getnames="true") 
   outcaslib="myCaslib" casout="DataSetA" replace;                                        
quit;

/* LOAD AN EXCEL FILE using proc casutil.                                     */
proc casutil;    
	droptable casdata="ICD_10" incaslib="myCaslib" quiet; 
    load file='/data/cas-landingzone/myPath/ICD_10.xlsx'         
      importoptions = (filetype="Excel" getnames="true") 
   outcaslib="myCaslib" casout="ICD_10" replace;
quit;


/******************************************************************************/
/* Import a CSV from the web.                                                 */
/* Downloads a file from SAS website, then loads the file to the CAS server.  */
/* The HTTP proc downloads the CreditScores dataset to a temporary file.      */
/* The UPLOAD statement uploads the table to the CAS server. The file is then */
/* received and stored as a temporary file until the file is loaded as an     */
/* in-memory table. After the table is loaded, the file is removed.           */
/******************************************************************************/
filename scrdata temp;                                
proc http                                             
   url='http://support.sas.com/documentation/onlinedoc/viya/exampledatasets/creditscores.csv'
   out=scrdata;                                     
quit;
proc cas;
   upload                                             
      path="%sysfunc(pathname(scrdata))"
      casOut={caslib="myCaslib", name="creditscores"}
      importOptions="csv";
run;
   table.tableInfo / caslib="mycaslib", table="creditscores";
quit;
filename scrdata clear;


/******************************************************************************/
/* WORKING WITH THE DATA                                                      */
/******************************************************************************/

/* Retrieve table information using tableInfo and retrieve details by using   */
/* the tableDetails, within proc cas.                                         */
proc cas;                                     
   table.tableInfo / name="creditscores";     
   table.tableDetails / name="creditscores";  
quit;

/* Retrieve rows from the table by using the Fetch action.                    */
/* The Fetch action is similar to the PRINT procedure where you can view your */
/* data on the Results tab.                                                   */
proc cas;                                                   
   table.fetch/table="creditscores",                        
      fetchVars={"Customer_Name", "State", "Age",           
                 "Income", "Payment_History", "Credit_Score",
                 "Total_Debt", "State_FIPS", "Region_FIPS"},
      sortby={{name="State",                               
         order="descending"}},                              
      index=false;                                          
quit;

/* Calculate the cardinality of the variables MAKE and ORIGIN, and outputs   */
/* the results to a table.                                                   */
proc cardinality data=myCaslib.creditscores outcard=myCaslib.creditscores_card;
var age Credit_Score;
run;

proc cas;                                                   
   table.fetch/table="creditscores_card";                                                             
quit;


/* Uses a DATA step to create a data set named CreditQualify.                 */
/* It creates variables using the LENGTH statement and conditionally filters  */
/* data by using the IF-THEN/ELSE statement.                                  */
data mycaslib.creditqualify / sessref=mysession;                                      
 set mycaslib.creditscores;                                                          
   length Age_Range $5;                                                                
   if Age in (18, 19, 20, 21, 22, 23, 24, 25) then Age_Range="18-25";                  
    else if Age in (26, 27, 28, 29, 30, 31, 32, 33, 34, 35) then Age_Range="26-35";     
      else if Age in (36, 37, 38, 39, 40, 41, 42, 43, 44, 45) then Age_Range="36-45";
        else if Age in (46, 47, 48, 49, 50, 51, 52, 53, 54, 55) then Age_Range="46-55";
          else if Age in (56, 57, 58, 59, 60, 61, 62, 63, 64) then Age_Range="56-64";
            else if Age>=65 then Age_Range="65+";
   length FICO_Rating $11;                                                             
   if 300<=Credit_Score<=570 then FICO_Rating="Very Poor";                             
     else if 580<=Credit_Score<=669 then FICO_Rating="Fair";
       else if 670<=Credit_Score<=739 then FICO_Rating="Good";
         else if 740<=Credit_Score<=799 then FICO_Rating="Very Good";
           else if Credit_Score>=800 then FICO_Rating="Exceptional";
   length Credit_Qualification $12;                                                    
   if Credit_Score>=740 then Credit_Qualification="Platinum";                          
     else if 650<=Credit_Score<=739 then Credit_Qualification="Gold";
       else if 450<=Credit_Score<=649 then Credit_Qualification="Secured Card";
         else if Credit_Score<=449 then Credit_Qualification="N/A";
run;

/* Export data as CSV. */
proc export data=mycaslib.creditqualify          
     outfile="/data/cas-landingzone/myPath/CreditQualify.csv"  
     dbms=csv                                    
     replace;                                     
run;

/* Generate a PDF. */
ods pdf (id=SapphireStyle) style=Sapphire file='/data/cas-landingzone/myPath/chart.pdf';
/*--HBar Plot-- from the snippets with the necessary adjustments. */
title 'Credit Score - Qualification';
proc sgplot data=mycaslib.creditqualify;
  hbar Credit_Qualification / response=Credit_Score  stat=mean  limits=both;
  yaxis display=(nolabel) grid;
  xaxis display=(nolabel);
run;
ods pdf close;
quit;


/******************************************************************************/
/* terminate the session */
cas mySession terminate;
