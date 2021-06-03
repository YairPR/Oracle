Graficar AWR
Para ello hay que sacar awr en "text" entre cada snap_id para 
tener varios archivos por ejemplo si queremos ver entre 2 horas y el tiempo de generacion de awr es cada 30 minutos tenemos q sacar 4 archivos.

Una vez los 4 archivos hay q ejecutar la shell
awr_parse.sh
-- Una vez generado el csv llevarlo al excel para sacar los datos y poder realizar graficas.
TAmbien se puede con tableu.
https://fatdba.com/2018/01/28/visualize-your-database-performance-statistics-using-tableau/
Ejemplo:
[oracle@rsdpedbadm03 awrreport]$ sh awr_parse.sh -p awwr_text_0621.lst > awr_02.csv

Info : Parsing file awwr_text_0621.lst at 2021-06-03 09:44:39
Info :                                 Filename = awwr_text_0621.lst
Info :                               AWR Format = 12
Info :                            Database Name = BDSAS
Info :                          Instance Number = 3
Info :                            Instance Name = BDSAS3
Info :                         Database Version = 11.2.0.4.0
Info :                              Cluster Y/N = Y
Info :                                 Hostname = rsdpedbadm03.rim
Info :                                  Host OS = Linux x86 64-bit
Info :                           Number of CPUs = 72
Info :                            Server Memory = 251.85
Info :                             DB Blocksize = 8K
Info :                               Begin Snap = 101267
Info :                               Begin Time = 03-Jun-21 00:00:04
Info :                                 End Snap = 101276
Info :                                 End Time = 03-Jun-21 04:30:21
Info :                             Elapsed Time = 270.29
Info :                                  DB Time = 8689.40
Info :                                      AAS = 32.1
Info :                                    Busy? = N
Info :                        Logical Reads/sec = 2847347.9
Info :                        Block Changes/sec = 706281.7
Info :                                Read IOPS = 8275.9
Info :                          Data Write IOPS = 741.7
Info :                          Redo Write IOPS = 128.1
Info :                         Total Write IOPS = 869.8
Info :                               Total IOPS = 9145.7
Info :                Read Throughput (MiB/sec) = 839.34
Info :          Data Write Throughput (MiB/sec) = 28.09
Info :          Redo Write Throughput (MiB/sec) = 3.69
Info :         Total Write Throughput (MiB/sec) = 31.78
Info :               Total Throughput (MiB/sec) = 871.12
Info :                           DB CPU Time ms = 186162
Info :                           DB CPU %DBTime = 35.7
Info :            Wait Class User IO  Num Waits = 132705906
Info :            Wait Class User IO  Wait Time = 96107
Info :            Wait Class User IO Latency ms = .724
Info :            Wait Class User IO    %DBTime = 18.4
Info :                           User Calls/sec = 1236.5
Info :                               Parses/sec = 479.7
Info :                          Hard Parses/sec = 0.8
Info :                               Logons/sec = 5.7
Info :                             Executes/sec = 49022.9
Info :                         Transactions/sec = 52.8
Info :                         Buffer Hit Ratio = 99.68
Info :                     In-Memory Sort Ratio = 100.00
Info :                    Log Switches    Total = 40
Info :                    Log Switches Per Hour = 8.88
Info :               Top 5 Timed Event1    Name = latch free
Info :               Top 5 Timed Event1   Class = Other
Info :               Top 5 Timed Event1   Waits = 1445630
Info :               Top 5 Timed Event1 Time ms = 187.
Info :               Top 5 Timed Event1 Average = .129
Info :               Top 5 Timed Event1 %DBTime = 36.0
Info :               Top 5 Timed Event2    Name = DB CPU
Info :               Top 5 Timed Event2   Class = 
Info :               Top 5 Timed Event2   Waits = 
Info :               Top 5 Timed Event2 Time ms = 186.
Info :               Top 5 Timed Event2 Average = 
Info :               Top 5 Timed Event2 %DBTime = 35.7
Info :               Top 5 Timed Event3    Name = cell single block physical rea
Info :               Top 5 Timed Event3   Class = User I/O
Info :               Top 5 Timed Event3   Waits = 96956430
Info :               Top 5 Timed Event3 Time ms = 49.9
Info :               Top 5 Timed Event3 Average = .001
Info :               Top 5 Timed Event3 %DBTime = 9.6
Info :               Top 5 Timed Event4    Name = direct path write temp
Info :               Top 5 Timed Event4   Class = User I/O
Info :               Top 5 Timed Event4   Waits = 832917
Info :               Top 5 Timed Event4 Time ms = 20.3
Info :               Top 5 Timed Event4 Average = .024
Info :               Top 5 Timed Event4 %DBTime = 3.9
Info :               Top 5 Timed Event5    Name = log file sequential read
Info :               Top 5 Timed Event5   Class = System I/O
Info :               Top 5 Timed Event5   Waits = 231325
Info :               Top 5 Timed Event5 Time ms = 11.6
Info :               Top 5 Timed Event5 Average = .050
Info :               Top 5 Timed Event5 %DBTime = 2.2
Info :      FG db file sequential read    Waits = 
Info :      FG db file sequential read  Time ms = 
Info :      FG db file sequential read  Average = 
Info :      FG db file sequential read  %DBTime = 
Info :      FG db file scattered read     Waits = 
Info :      FG db file scattered read   Time ms = 
Info :      FG db file scattered read   Average = 
Info :      FG db file scattered read   %DBTime = 
Info :      FG direct path read           Waits = 71413
Info :      FG direct path read         Time ms = 498
Info :      FG direct path read         Average = 6.974
Info :      FG direct path read         %DBTime = .1
Info :      FG direct path write          Waits = 54632
Info :      FG direct path write        Time ms = 1839
Info :      FG direct path write        Average = 33.662
Info :      FG direct path write        %DBTime = .4
Info :      FG direct path read temp      Waits = 3572751
Info :      FG direct path read temp    Time ms = 7144
Info :      FG direct path read temp    Average = 2.000
Info :      FG direct path read temp    %DBTime = 1.4
Info :      FG direct path write temp     Waits = 832917
Info :      FG direct path write temp   Time ms = 20304
Info :      FG direct path write temp   Average = 24.377
Info :      FG direct path write temp   %DBTime = 3.9
Info :      FG log file sync              Waits = 881595
Info :      FG log file sync            Time ms = 1516
Info :      FG log file sync            Average = 1.720
Info :      FG log file sync            %DBTime = .3
Info :      BG db file parallel write     Waits = 1371851
Info :      BG db file parallel write   Time ms = 36481
Info :      BG db file parallel write   Average = 26.593
Info :      BG db file parallel write   %BGTime = 61.0
Info :      BG log file parallel write    Waits = 2077231
Info :      BG log file parallel write  Time ms = 845
Info :      BG log file parallel write  Average = .407
Info :      BG log file parallel write  %BGTime = 1.4
Info :      BG log file sequential read   Waits = 60507
Info :      BG log file sequential read Time ms = 2866
Info :      BG log file sequential read Average = 47.366
Info :      BG log file sequential read %BGTime = 4.8
Info :      OS busy time              (sec/100) = 25727279
Info :      OS idle time              (sec/100) = 90177486
Info :      OS iowait time            (sec/100) = 11031
Info :      OS sys time               (sec/100) = 2436157
Info :      OS user time              (sec/100) = 22792490
Info :      OS cpu wait time          (sec/100) = 
Info :      OS resource mgr wait time (sec/100) = 401
Info :                       Data Guard in use? = Y
Info :                          Exadata in use? = Y
Info :              Wait Class Admin  Num Waits = 4
Info :              Wait Class Admin  Wait Time = 1
Info :              Wait Class Admin Latency ms = 250.000
Info :              Wait Class Admin    %DBTime = 0.0
Info :        Wait Class Application  Num Waits = 71513
Info :        Wait Class Application  Wait Time = 718
Info :        Wait Class Application Latency ms = 10.040
Info :        Wait Class Application    %DBTime = 0.1
Info :            Wait Class Cluster  Num Waits = 35895614
Info :            Wait Class Cluster  Wait Time = 14904
Info :            Wait Class Cluster Latency ms = .415
Info :            Wait Class Cluster    %DBTime = 2.9
Info :             Wait Class Commit  Num Waits = 881595
Info :             Wait Class Commit  Wait Time = 1516
Info :             Wait Class Commit Latency ms = 1.720
Info :             Wait Class Commit    %DBTime = 0.3
Info :        Wait Class Concurrency  Num Waits = 1419126
Info :        Wait Class Concurrency  Wait Time = 8841
Info :        Wait Class Concurrency Latency ms = 6.230
Info :        Wait Class Concurrency    %DBTime = 1.7
Info :      Wait Class Configuration  Num Waits = 12419
Info :      Wait Class Configuration  Wait Time = 377
Info :      Wait Class Configuration Latency ms = 30.357
Info :      Wait Class Configuration    %DBTime = 0.1
Info :            Wait Class Network  Num Waits = 19403814
Info :            Wait Class Network  Wait Time = 5569
Info :            Wait Class Network Latency ms = .287
Info :            Wait Class Network    %DBTime = 1.1
Info :              Wait Class Other  Num Waits = 2810666
Info :              Wait Class Other  Wait Time = 193019
Info :              Wait Class Other Latency ms = 68.674
Info :              Wait Class Other    %DBTime = 37.0
Info :          Wait Class System IO  Num Waits = 1207622
Info :          Wait Class System IO  Wait Time = 12605
Info :          Wait Class System IO Latency ms = 10.438
Info :          Wait Class System IO    %DBTime = 2.4
Info :  Histogram db file sequential read  <1ms = 
Info :  Histogram db file sequential read  <2ms = 
Info :  Histogram db file sequential read  <4ms = 
Info :  Histogram db file sequential read  <8ms = 
Info :  Histogram db file sequential read <16ms = 
Info :  Histogram db file sequential read <32ms = 
Info :  Histogram db file sequential read   <1s = 
Info :  Histogram db file sequential read   >1s = 
Info :  Histogram log file parallel write  <1ms = 94.5
Info :  Histogram log file parallel write  <2ms = 4.0
Info :  Histogram log file parallel write  <4ms = 1.0
Info :  Histogram log file parallel write  <8ms = .4
Info :  Histogram log file parallel write <16ms = .1
Info :  Histogram log file parallel write <32ms = .0
Info :  Histogram log file parallel write   <1s = .0
Info :  Histogram log file parallel write   >1s = 
Info : No more files found
Info : 
Info : ______SUMMARY______
Info : Files found       : 1
Info : Files processed   : 1
Info : Processing errors : 0
Info : 
Info : Completed successfully
