A simple x86_64 Linux assembly program for comparing the percentage of matching bytes between two files. Why do this? I need it to check the accuracy of another program I am writing in Ruby. I have a known correct answer... and I need to find how close the test subject is to the correct one. Plus, bowties are cool!

Douglas
Offset of stats:
00h 00d: 0000 0801            ; File Type
04h 04d: 003e 1c3b            ; I-node number
08h 08d: 0001                 ; Link count
0Ah 10d: 81b4                 ; File mode
0Ch 12d: 03e8                 ; User ID#
0Eh 14d: 03e8                 ; Group ID#
10h 16d: 0000 0000            ; Padding ???
14h 20d: 0000 01ce            ; File Size
18h 24d: 0000 1000            ; Preffered block size
1Ch 28d: 0000 0008            ; Blocks allocated
20h 32d: 518e 8c73  007b 4578 ; Last status change TIME:NSEC
28h 40d: 518c 8576  2385 905e ; Last file access TIME:NSEC
30h 48d: 518c 8576  2385 905e ; Last file mod TIME:NSEC
38h 56d: 0000 0000  0000 0000
64: 00