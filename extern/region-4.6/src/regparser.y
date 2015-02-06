
%{
/*                                                                
**  Copyright (C) 2007  Smithsonian Astrophysical Observatory 
*/                                                                

/*                                                                          */
/*  This program is free software; you can redistribute it and/or modify    */
/*  it under the terms of the GNU General Public License as published by    */
/*  the Free Software Foundation; either version 3 of the License, or       */
/*  (at your option) any later version.                                     */
/*                                                                          */
/*  This program is distributed in the hope that it will be useful,         */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of          */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           */
/*  GNU General Public License for more details.                            */
/*                                                                          */
/*  You should have received a copy of the GNU General Public License along */
/*  with this program; if not, write to the Free Software Foundation, Inc., */
/*  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.             */
/*                                                                          */

#include "region_priv.h"
#include "regpar.h"
int test_link_jcm( void );
#include <ctype.h>
extern char     *regParseStr;
extern char     *regParseStrEnd;
extern regRegion *my_Gregion;
static int world_coord;
static int world_size;
%}


%token REG_CIRCLE REG_BOX REG_POLY REG_PIE REG_RECT REG_ELL REG_ROTBOX REG_ANNULUS
%token REG_SECTOR REG_POINT REG_ROTRECT REG_NEG REG_AND REG_OR REG_MINUS 
%token REG_FIELD REG_TEXT REG_STRING REG_LINE
%token <dval> REG_NUMBER 
%token  colName

%union {
  double dval;
  char str[1024];
  regRegion* my_region;
  regShape* my_shape;
  struct polyside
  { double *polyX; double *polyY; long polyS; } PolySide;
}


%type <my_shape> reg_shape
%type <my_region> reg_comp
%type <PolySide> reg_ordered_pair
%type <dval> reg_xcoord
%type <dval> reg_ycoord
%type <dval> reg_angle
%type <dval> reg_size
%type <dval> reg_value
%%

  
reg_comp:
   reg_comp REG_OR reg_shape { $$ = $1; regAddShape( $1, regOR, $3 );  }
 | reg_comp reg_shape  { $$ = $1; regAddShape( $1, regOR, $2 );  }
 | reg_comp REG_AND reg_shape { $$ = $1; regAddShape( $1, regAND, $3 ); }
 | reg_comp REG_MINUS reg_shape { $$ = $1; regNegate( $3 ); regAddShape( $1, regAND, $3 ); }
 | REG_OR reg_shape {
                $$ = regCreateRegion( NULL, NULL );
                regAddShape( $$ , regOR, $2 ); 
		my_Gregion = $$;
             }
 | reg_shape {
                $$ = regCreateRegion(NULL, NULL );
                regAddShape( $$ , regOR, $1 ); 
		my_Gregion = $$;
             }
 | error "" { yyerrok; }

;


reg_xcoord:
        reg_value
          {  $$ = $1; world_coord = 0; }
     |  reg_value 'd'
          {  $$ = $1; world_coord = 1; }
     |  REG_NUMBER ':' REG_NUMBER ':' REG_NUMBER  
          {
           double ndeg, nmin, nsec, nval;
           ndeg = $1; nmin = $3; nsec = $5;
           nval = ( ndeg + nmin / 60.0 + nsec / 3600.0 );
           world_coord = 1;
           $$ = nval * 15.0;
          }
;

reg_ycoord:
        reg_value
          {  $$ = $1; world_coord = 0; }
     |  reg_value 'd'
          {  $$ = $1; world_coord = 1; }
     |  REG_NUMBER ':' REG_NUMBER ':' REG_NUMBER  
          {
           double ndeg, nmin, nsec, nval;
           ndeg = $1; nmin = $3; nsec = $5;
           nval = ( ndeg + nmin / 60.0 + nsec / 3600.0 );
           world_coord = 1;
           $$ = nval;
          }
     |  REG_MINUS REG_NUMBER ':' REG_NUMBER ':' REG_NUMBER  
          {  /* Special care in case of -00:00:01 */
           double ndeg, nmin, nsec, nval;
           ndeg = $2; nmin = $4; nsec = $6;
           nval = ( ndeg + nmin / 60.0 + nsec / 3600.0 );
           world_coord = 1;
           $$ = -nval;
          }
;

reg_value:
	REG_NUMBER          
          {  $$ = $1; }
     |  REG_MINUS REG_NUMBER
          {  $$ = -$2;}
;

reg_angle:
	reg_value          
          {  $$ = $1; }
      | reg_value '\''
          {  $$ = $1 / 60.0; }
      | reg_value '\"'
          {  $$ = $1 / 3600.0; }
      | reg_value 'd'
          {  $$ = $1; }
;

reg_size:
        reg_value
          {  $$ = $1; world_size = 0; }
      | reg_value 'p'
          {  $$ = $1; world_size = 0; }
      | reg_value 'i'     
          {  $$ = $1; world_size = 0;  /* This is logical coords; we need to fix this */ }
      | reg_value 'd'
          {  $$ = $1; world_size = 1; }
      | reg_value '\''
          {  $$ = $1 / 60.0; world_size = 1; }
      | reg_value '\'' '\''
          {  $$ = $1 / 3600.0; world_size = 1; }
      | reg_value '\"'
          {  $$ = $1 / 3600.0; world_size = 1; }
;


reg_shape: 
    REG_FIELD '(' ')' 
     { 
       $$ = regCreateNewWorldShape( regFIELD, regInclude, NULL, NULL, 0, NULL, NULL, world_coord, world_size );
       if ( $$ == NULL ) {
	 my_Gregion = NULL;
	 YYERROR;
       }
     }
  | REG_NEG REG_FIELD '(' ')'
     { 
       $$ = regCreateNewWorldShape( regFIELD, regExclude, NULL, NULL, 0, NULL, NULL, world_coord, world_size );
       if ( $$ == NULL ) {
	 my_Gregion = NULL;
	 YYERROR;
       }
     }
  | REG_TEXT '(' reg_xcoord ',' reg_ycoord ',' REG_STRING ')' 
     { 
       /* We just ignore the text, treat it as a point */
       double x[1]; double y[1];
       x[0]=$3; y[0]=$5;
       $$ = regCreateNewWorldShape( regPOINT, regInclude, x, y, 1, NULL, NULL, world_coord, 0 );
       if ( $$ == NULL ) {
	 my_Gregion = NULL;
	 YYERROR;
       }
     }
  | REG_CIRCLE '(' reg_xcoord ',' reg_ycoord ',' reg_size ')' 
     { 
       double x[1]; double y[1]; double r[1];
       x[0]=$3; y[0]=$5; r[0]=$7;

       if ( r[0] < 0 ) {
	 fprintf( stderr, "ERROR: circle radius must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regCIRCLE, regInclude, x, y, 1, r, NULL, world_coord, world_size );
         if ( $$ == NULL ) {
	   my_Gregion = NULL;
	   YYERROR;
         }
     }
  | REG_NEG REG_CIRCLE '(' reg_xcoord ',' reg_ycoord ',' reg_size ')' 
     { 
       double x[1]; double y[1]; double r[1];
       x[0]=$4; y[0]=$6; r[0]=$8;
       if ( r[0] < 0 ) {
	 fprintf( stderr, "ERROR: circle radius must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regCIRCLE, regExclude, x, y, 1, r, NULL, world_coord, world_size );
         if ( $$ == NULL ) {
  	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_ANNULUS '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ')'
     {
       double x[1]; double y[1]; double r[2];
       x[0]=$3; y[0]=$5; r[0]=$7; r[1]=$9;

       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: annulus radius must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else if (r[0] > r[1]){
	 fprintf( stderr, "ERROR: outer annuls radius must be >= inner radius\n");
	 my_Gregion = NULL;
	 YYERROR;
       }
       else
	 $$ = regCreateNewWorldShape( regANNULUS, regInclude, x, y, 1, r, NULL, world_coord, world_size);
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_NEG REG_ANNULUS '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ')'
     {
       double x[1]; double y[1]; double r[2];
       x[0]=$4; y[0]=$6; r[0]=$8; r[1]=$10;

       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: annulus radius must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else if (r[0] > r[1]){
	 fprintf( stderr, "ERROR: outer annuls radius must be >= inner radius\n");
	 my_Gregion = NULL;
	 YYERROR;
       }
       else
	 $$ = regCreateNewWorldShape( regANNULUS, regExclude, x, y, 1, r, NULL, world_coord, world_size);
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_BOX '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ')'
     {
       double x[1]; double y[1]; double r[2];
       x[0]=$3; y[0]=$5; r[0]=$7; r[1]=$9;

       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: box lengths must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regBOX, regInclude, x, y, 1, r, NULL, world_coord, world_size);
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_NEG REG_BOX '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ')'
     {
       double x[1]; double y[1]; double r[2];
       x[0]=$4; y[0]=$6; r[0]=$8; r[1]=$10;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: box lengths must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regBOX, regExclude, x, y, 1, r, NULL, world_coord, world_size);
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_BOX '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ',' reg_angle ')'
     {
       double x[1]; double y[1]; double r[2]; double a[1];
       x[0]=$3; y[0]=$5; r[0]=$7; r[1]=$9; a[0]=$11;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: box lengths must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regROTBOX, regInclude, x, y, 1, r, a, world_coord, world_size);
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_NEG REG_BOX '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ',' reg_angle ')'
     {
       double x[1]; double y[1]; double r[2]; double a[1];
       x[0]=$4; y[0]=$6; r[0]=$8; r[1]=$10; a[0]=$12;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: box lengths must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regROTBOX, regExclude, x, y, 1, r, a, world_coord, world_size);
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_ROTBOX '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ',' reg_angle ')'
     {
       double x[1]; double y[1]; double r[2]; double a[1];
       x[0]=$3; y[0]=$5; r[0]=$7; r[1]=$9; a[0]=$11;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: box lengths must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regROTBOX, regInclude, x, y, 1, r, a, world_coord, world_size);
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_NEG REG_ROTBOX '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ',' reg_angle ')'
     {
       double x[1]; double y[1]; double r[2]; double a[1];
       x[0]=$4; y[0]=$6; r[0]=$8; r[1]=$10; a[0]=$12;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: box lengths must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regROTBOX, regExclude, x, y, 1, r, a, world_coord, world_size);
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_PIE '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ',' reg_angle ',' reg_angle ')'
     {
       double x[1]; double y[1]; double a[2]; double r[2];
       x[0]=$3; y[0]=$5; r[0]=$7; r[1]=$9;  a[0]=$11; a[1]=$13;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: pie radii must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else if ( r[0] > r[1] ) {
	 fprintf( stderr, "ERROR: outer annuls radius must be >= inner radius\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regPIE, regInclude, x, y, 1, r, a, world_coord, world_size );
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_NEG REG_PIE '(' reg_xcoord ',' reg_ycoord ',' reg_size ','  reg_size ',' reg_angle ',' reg_angle ')'
     {
       double x[1]; double y[1]; double a[2]; double r[2];
       x[0]=$4; y[0]=$6; r[0] = $8; r[1] = $10; a[0]=$12; a[1]=$14;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: pie radii must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else if ( r[0] > r[1] ) {
	 fprintf( stderr, "ERROR: outer annuls radius must be >= inner radius\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regPIE, regExclude, x, y, 1, r, a, world_coord, world_size );
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_SECTOR '(' reg_xcoord ',' reg_ycoord ',' reg_angle ',' reg_angle ')'
     {
       double x[1]; double y[1]; double a[2];
       x[0]=$3; y[0]=$5; a[0]=$7; a[1]=$9;
       $$ = regCreateNewWorldShape( regSECTOR, regInclude, x, y, 1, NULL, a, world_coord, 0 );
       if ( $$ == NULL ) {
 	 my_Gregion = NULL;
	 YYERROR;
       }
     }
   | REG_NEG REG_SECTOR '(' reg_xcoord ',' reg_ycoord ',' reg_angle ',' reg_angle ')'
     {
       double x[1]; double y[1]; double a[2];
       x[0]=$4; y[0]=$6; a[0]=$8; a[1]=$10;
       $$ = regCreateNewWorldShape( regSECTOR, regExclude, x, y, 1, NULL, a, world_coord, 0 );
       if ( $$ == NULL ) {
 	 my_Gregion = NULL;
	 YYERROR;
       }
     }
   | REG_POINT '(' reg_xcoord ',' reg_ycoord ')'
     {
       double x[1]; double y[1];
       x[0]=$3; y[0]=$5;
       $$ = regCreateNewWorldShape( regPOINT, regInclude, x, y, 1, NULL, NULL, world_coord, 0 );
       if ( $$ == NULL ) {
 	 my_Gregion = NULL;
	 YYERROR;
       }
     }
   | REG_NEG REG_POINT '(' reg_xcoord ',' reg_ycoord ')'
     {
       double x[1]; double y[1];
       x[0]=$4; y[0]=$6;
       $$ = regCreateNewWorldShape( regPOINT, regExclude, x, y, 1, NULL, NULL, world_coord, 0 );
       if ( $$ == NULL ) {
 	 my_Gregion = NULL;
	 YYERROR;
       }
     } 
   | REG_RECT '(' reg_xcoord ',' reg_ycoord ',' reg_xcoord ',' reg_ycoord ')'
     {
       double x[2]; double y[2];
       x[0]=$3; x[1]=$7; y[0]=$5;y[1]=$9;
       $$ = regCreateNewWorldShape( regRECTANGLE, regInclude, x, y, 2, NULL, NULL, world_coord, 0 );
       if ( $$ == NULL ) {
 	 my_Gregion = NULL;
	 YYERROR;
       }
     }
   | REG_NEG REG_RECT '(' reg_xcoord ',' reg_ycoord ',' reg_xcoord ',' reg_ycoord ')'
     {
       double x[2]; double y[2];
       x[0]=$4; x[1]=$8; y[0]=$6; y[1]=$10;
       $$ = regCreateNewWorldShape( regRECTANGLE, regExclude, x, y, 2, NULL, NULL, world_coord, 0 );
       if ( $$ == NULL ) {
 	 my_Gregion = NULL;
	 YYERROR;
       }
     }
   | REG_LINE '(' reg_xcoord ',' reg_ycoord ',' reg_xcoord ',' reg_ycoord ')'
     {
       /* RegLine doesn't work correctly; need to calculate angle */
       double x[2]; double y[2];
       x[0]=$3; x[1]=$7; y[0]=$5;y[1]=$9;
       $$ = regCreateNewWorldShape( regRECTANGLE, regInclude, x, y, 2, NULL, NULL, world_coord, 0 );
       if ( $$ == NULL ) {
 	 my_Gregion = NULL;
	 YYERROR;
       }
     }
   | REG_NEG REG_LINE '(' reg_xcoord ',' reg_ycoord ',' reg_xcoord ',' reg_ycoord ')'
     {
       double x[2]; double y[2];
       x[0]=$4; x[1]=$8; y[0]=$6; y[1]=$10;
       $$ = regCreateNewWorldShape( regRECTANGLE, regExclude, x, y, 2, NULL, NULL, world_coord, 0 );
       if ( $$ == NULL ) {
 	 my_Gregion = NULL;
	 YYERROR;
       }
     }
   | REG_ELL '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ',' reg_angle ')'
     {
       double x[1]; double y[1]; double r[2]; double a[1];
       x[0]=$3; y[0]=$5; r[0]=$7; r[1]=$9; a[0]=$11;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: ellipse radii must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regELLIPSE, regInclude, x, y, 1, r, a, world_coord, world_size );
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_NEG REG_ELL '(' reg_xcoord ',' reg_ycoord ',' reg_size ',' reg_size ',' reg_angle ')'
     {
       double x[1]; double y[1]; double r[2]; double a[1];
       x[0]=$4; y[0]=$6; r[0]=$8; r[1]=$10; a[0]=$12;
       if (( r[0] < 0 ) || (r[1] < 0 )) {
	 fprintf( stderr, "ERROR: ellipse radii must be positive\n");
	 my_Gregion = NULL;
	 YYERROR;
       } else
	 $$ = regCreateNewWorldShape( regELLIPSE, regExclude, x, y, 1, r, a, world_coord, world_size );
         if ( $$ == NULL ) {
 	   my_Gregion = NULL;
	   YYERROR;
         }
     }
   | REG_POLY '(' reg_ordered_pair ')'
     { 
       $$ = regCreateNewWorldShape( regPOLYGON, regInclude, $3.polyX, $3.polyY, 
			    $3.polyS, NULL, NULL, world_coord, 0 );
       if ( $$ == NULL ) {
	 my_Gregion = NULL;
	 YYERROR;
       }

       free( $3.polyX );
       free( $3.polyY );
     }
   | REG_NEG REG_POLY '(' reg_ordered_pair ')'
     { 
       $$ = regCreateNewWorldShape( regPOLYGON, regExclude, $4.polyX, $4.polyY, 
			    $4.polyS, NULL, NULL, world_coord, 0 );
       free( $4.polyX );
       free( $4.polyY );
       if ( $$ == NULL ) {
	 my_Gregion = NULL;
	 YYERROR;
       }
     }

;

reg_ordered_pair:
     reg_ordered_pair ',' reg_xcoord ',' reg_ycoord
   {
     $$ = $1;
     $$.polyS += 1;
     $$.polyX = (double*)realloc( $$.polyX, $$.polyS *sizeof(double));
     $$.polyY = (double*)realloc( $$.polyY, $$.polyS *sizeof(double));
     $$.polyX[$$.polyS -1] = $3;
     $$.polyY[$$.polyS -1] = $5;
     }
   | reg_xcoord ',' reg_ycoord {
     $$.polyS = 1;
     $$.polyX = (double*)calloc(1,sizeof(double));
     $$.polyY = (double*)calloc(1,sizeof(double));
     $$.polyX[0] = $1;
     $$.polyY[0] = $3;
   }
;
%%


regRegion* regParse( char* buf )
{
  regRegion* regptr;
  char* ptr;
  /* my_Gregion is declared externally*/
  my_Gregion = NULL;
  regParseStr = buf;

  if ( !buf )
   return NULL;
  ptr = buf;
  while( *ptr == ' ' || *ptr == '(' ) ptr++;
  if ( !isalpha( *ptr ) && *ptr != '!' )
  {
   /* Not a region ( always begins with alpha or ! ) */
   return NULL;
  }

  regParseStrEnd = buf + strlen( buf );
/*  yydebug = 1; */
    yyparse();
 regptr = my_Gregion;
 return regptr;
}


void yyerror( char* msg )
{
  
  my_Gregion = NULL;
  return;
}

int yywrap( void )
{
  return 1;
}



