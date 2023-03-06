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
/*  Load SAS data set from a SAS Base engine library (library.tableName)     */
/*  into the specified caslib ("myCaslib") and save as "targetTableName".    */
/*****************************************************************************/
proc casutil;
    droptable casdata="IRIS" incaslib="myCaslib" quiet;
	load data=SASHELP.IRIS outcaslib="myCaslib" casout="Iris";
run;

/*****************************************************************************/
/*  Load SAS data set from a Base engine library into the "myCaslib"         */
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
   table.tableInfo / name="cars";     
   table.tableDetails / name="cars";  
quit;

/* Retrieve rows from the table by using the Fetch action.                    
   The Fetch action is similar to the PRINT procedure where you can view your 
   data on the Results tab.                                                   */
proc cas;                                                   
   table.fetch/table="cars",                        
      fetchVars={"Make", "Model", "Type", "Origin", "Horsepower"},
      sortby={{name="Horsepower", order="descending"}},                              
      index=true;                                          
quit;

/* Calculate the cardinality of the variables MAKE and ORIGIN, and outputs   
   the results to a table.                                                   */
proc cardinality data=myCaslib.cars outcard=myCaslib.cars_card;
var MAKE ORIGIN;
run;

proc cas;                                                   
   table.fetch/table="cars_card";                                                             
quit;


/* Use a DATA step to create a data set named cars_select.
   It uses Where to select only the interesting ones, creates a variable using
   the LENGTH statement and conditionally filters data by using  IF-THEN/ELSE.*/
data myCaslib.cars_select;                                      
 set myCaslib.cars (where=(Origin="Europe"and Type="Sports"));    
   length HP_Range $6;                                                                
   if Horsepower >=350 then HP_Range="High";                          
     else if 250<=Horsepower<350 then HP_Range="Medium";
       else HP_Range="Low";
run;

/* Export data as CSV. */
proc export data=mycaslib.cars_select          
     outfile="/data/cas-landingzone/myPath/cars_select.csv"  
     dbms=csv                                    
     replace;                                     
run;

/* Generate a PDF. */
ods pdf file='/data/cas-landingzone/myPath/CarsSelected.pdf';
title 'Selected European Sports Cars';
proc cas;                                                   
   table.fetch/table="cars_select",                        
      fetchVars={"Make", "Model", "HP_Range", "Horsepower", "Invoice"},
      sortby={{name="Invoice", order="descending"}},                              
      index=true
      to=23;                                          
quit;

proc sgplot data=mycaslib.cars_select;
  hbar HP_Range / categoryorder=respdesc;
  yaxis  Values=('High' 'Medium' 'Low');
run;
ods pdf close;
quit;

/* Save the in-memory table into the Global Caslib Public as a physical dataset */ 
proc casutil;
    save casdata="cars_select"  incaslib="mycaslib" 
          casout="cars_select" outcaslib="Public" replace;
quit;

/******************************************************************************/
/* terminate the session */
cas mySession terminate;
