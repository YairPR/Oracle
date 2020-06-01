Total Size:
-- The view (V$sga) display summary information about the system global area (SGA).
*Name: Sga component group
*Value: Memory size (in bytes)

select sum(value)/1024/1024/1024 Total_size_In_GB from V$sga
=================================================================
Free Size
The View (V$SGASTAT) displays detailed information on the system global area (SGA).

Let’s have a short explanation of all column of the v$sgastat parameter:
I)POOL - Designates the pool in which the memory in NAME resides:
*Shared pool = Memory is allocated from the shared pool
*Large pool = Memory is allocated from the large pool
*Java pool = Memory is allocated from the Java pool
*Stream pool = Memory is allocated from the stream pool
II)NAME - SGA component name
III)BYTES - The Memory size in bytes

Select POOL, Round(bytes/1024/1024,0) Free_Memory_In_MB
  From V$sgastat
  Where Name Like '%free memory%';

The Total free space 

Select sum(bytes/1024/1024) Free_Memory_In_MB
 From VWhere Name Like '%free memory%';
 
 
 
 
