/*****************************************************************************/
/*  Create a default CAS session and create SAS librefs for existing caslibs */
/*  so that they are visible in the SAS Studio Libraries tree.               */
/*****************************************************************************/
cas; 
caslib _all_ assign;

/*****************************************************************************/
/* Generate the Report PDF                                                */
/*****************************************************************************/
title;
ods graphics on;
ods PDF file="/home/sbreff/Docs/QC_PDF_Report.pdf";
title 'QA PDF Report';

Data PUBLIC.ManuData / single=yes;
Set PUBLIC.'INTEGRATED MANUFACTURING DATA'n;
id = _N_;
if _N_ lt 31 then Month = "1";
	else if _N_ lt 61 then Month = "2";
         else Month = "3";
run;

/*****************************************************************************/
ods graphics / width=20cm height=12cm imagemap;
PROC CAPABILITY data=PUBLIC.'INTEGRATED MANUFACTURING DATA'n
          CIBASIC(TYPE=TWOSIDED ALPHA=0.05)
          MU0=0;
     VAR Dissolution;
     ;
	 SPEC LSL=70 WLSL=2 LLSL=2 CLSL=BLACK CLEFT=RED;
     HISTOGRAM  Dissolution / NORMAL (    W=1 L=1 COLOR=RED  MU=EST SIGMA=EST)
     CAXIS=PURPLE
     CTEXT=BLACK
     CFRAME=WHITE
     CBARLINE=BLACK
     CFILL=GRAY
;
RUN;

proc sgplot data=PUBLIC.'INTEGRATED MANUFACTURING DATA'n;
    title height=12pt "Dissolution Test - Line";
    vline 'API Lot No'n /        
    response=Dissolution  lineattrs=(thickness=2  color=CX003399);
    yaxis max=85  grid  label="Dissolution rate in 1h" ;
    refline 70 / axis=y lineattrs=(thickness=2 color=red)
	   label="lower control level" labelattrs=(color=red);
    refline 82 / axis=y lineattrs=(thickness=2 color=red)
	   label="upper control level" labelattrs=(color=red);
run;
title "";

/*****************************************************************************/
PROC SHEWHART DATA=PUBLIC.ManuData (rename=(Month=_phase_));
      IRCHART     (Dissolution)  * 'API Lot No'n     /
	  readphases = ('1' '2' '3')
      cframe     = ( vibg   ywh    ligr )
      phaselegend
      cphaseleg  = black
	  markers
      phaseref
      nolegend
     TESTS= 1 2 3 4 5 6 7 8
     CTESTS=RED
     ZONELABELS
     TESTLABEL1='1'
     TESTLABEL2='2'
     TESTLABEL3='3'
     TESTLABEL4='4'
     TESTLABEL5='5'
     TESTLABEL6='6'
     TESTLABEL7='7'
     TESTLABEL8='8'
     SIGMAS=3
     CAXIS=BLACK
     WAXIS=1
     CTEXT=BLACK
     CINFILL=CXA9A9A9
     CLIMITS=BLACK
     TOTPANELS=1
     CCONNECT=BLUE
     COUTFILL=RED
     CFRAME=CXD3D3D3
     LIMITN=2
;
     ;
RUN;


ods graphics;
ods PDF close;