000200 IDENTIFICATION DIVISION.
000300 PROGRAM-ID. SEQSIMP1.
000400* This program just reads an input file and
000500* writes every record to the output file
000600* this is actually a copy program
000700* put many comments here -
000800* explain the program, inputs, outputs
000900* author, date, etc.
001000 ENVIRONMENT DIVISION.
001100 CONFIGURATION SECTION.
001200 INPUT-OUTPUT SECTION.
001300 FILE-CONTROL.
001400*  INPUT FILE: PARTS
001500     SELECT IN-FILE  ASSIGN PARTS.
001800*  OUTPUT FILE: SEND TO PRINTER
001900     SELECT OUT-FILE ASSIGN OUTFILE.
002200 DATA DIVISION.
002300 FILE SECTION.
002400 FD  IN-FILE
002410     RECORDING MODE IS F
002700     RECORD CONTAINS 80 CHARACTERS.
003000 01  IN-RECORD.
003010*     PICTURES MUST CORRESPOND TO THE ACTUAL INPUT FILE
003020      05  PART-NUMBER     PIC X(6).
003040      05  filler          pic x.
003050      05  PART-DESC       PIC X(30).
003060      05  filler          pic x.
003070      05  QTY-ON-HAND     PIC 9(3).
003080      05  filler          pic x.
003090      05  QTY-ON-ORDER    PIC 9(3).
003100      05  filler          pic x.
003110      05  QTY-ON-RESERVE  PIC 9(3).
003120      05  filler          pic x.
003130      05  PART-PRICE      PIC 9(3)V99.
003130      05  UNUSED          PIC X(25).
003140
003200 FD  OUT-FILE
003210     RECORDING MODE IS F
003600     RECORD CONTAINS 80 CHARACTERS.
003700 01  OUT-RECORD PIC X(80).
003800
003900 WORKING-STORAGE SECTION.
004000 01  SWITCHES.
004100      05  FILE-AT-END     PIC X  VALUE 'N'.
004200
004300 01  RECORD-COUNT          PIC S9(7) PACKED-DECIMAL VALUE +0.
004400 01  DISPLAY-RECORD-COUNT  PIC Z(6)9.
006000
006100 01  WS-OUT-RECORD.
006200      05  OUT-PART-NUMBER     PIC X(6).
006300      05  filler          pic x.
006400      05  OUT-PART-DESC       PIC X(30).
006500      05  filler          pic x.
006600      05  OUT-QTY-ON-HAND     PIC 9(3).
006700      05  filler          pic x.
006800      05  OUT-QTY-ON-ORDER    PIC 9(3).
006900      05  filler          pic x.
007000      05  OUT-QTY-ON-RESERVE  PIC 9(3).
007100      05  filler          pic x.
007200      05  OUT-PART-PRICE      PIC 9(3)V99.
007300      05  OUT-UNUSED          PIC X(25).
007400
007500 PROCEDURE DIVISION.
007600**   Please keep the first part of your program simple
007700**   perform beginning, perform main loop til no more records,
007800**   perform the end
007900**   please note the style of using periods
008000**   only before and after paragraph names
008100**   and at physical end of program.
008200     PERFORM INITIALIZATION
008300     PERFORM PROCESS-ALL
008400**       UPPER CASE Y, PLEASE
008500         UNTIL FILE-AT-END = 'Y'
008600     PERFORM TERMINATION
008700     GOBACK.
008800
008900 INITIALIZATION.
009000*    In this part you do the things you need to do once only
009100*    at the beginning of the program
009200*    please read the first record! This logic depends on it
009300     OPEN INPUT IN-FILE
009400          OUTPUT OUT-FILE
009500     PERFORM READ-PAR.
009600
009700 PROCESS-ALL.
009800*    This is performed once for each record read
009900*    it is the most important part of the program
010000*    you generally do three things:
010100*      process input record and/ or format output record
010200*      write the output record
010300*      read next input record (don't forget this)
010400*    formatting the output record:
010500*    in a simple program like this you could move
010600*    the whole record instead of the individual fields
010700*    as shown here
010800     MOVE PART-NUMBER    TO OUT-PART-NUMBER
010900     MOVE PART-DESC      TO OUT-PART-DESC
011000     MOVE QTY-ON-HAND    TO OUT-QTY-ON-HAND
011100     MOVE QTY-ON-ORDER   TO OUT-QTY-ON-ORDER
011200     MOVE QTY-ON-RESERVE TO OUT-QTY-ON-RESERVE
011300     MOVE PART-PRICE     TO OUT-PART-PRICE
011400     MOVE UNUSED         TO OUT-UNUSED
011500*    I have adopted the style of the write from
011600*    there is very little controversy over this
011700*    because it would be awkward to write different types of
011800*    print lines if you didn't do a write from
011900*    this will be more obvious in programs that do reports
012000     WRITE OUT-RECORD    FROM WS-OUT-RECORD
012100     PERFORM READ-PAR.
012200
012300 TERMINATION.
012400*    Here you do what you need to do once only
012500*    after all records have been processed
012600*    and you are ready to end
012700*    this might include final totals, for example
012800*    move record-count to display-record-count
012900*    display puts the data item directly to the printer
013000*    DISPLAY DISPLAY-RECORD-COUNT
013100     CLOSE IN-FILE OUT-FILE.
013200
013300 READ-PAR.
013600     READ IN-FILE 
013700         AT END MOVE 'Y' TO FILE-AT-END
013800*        I included the code to count input records
013900*        although it is commented out
014000*        not at end add 1 to record-count
014100     END-READ.
