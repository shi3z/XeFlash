variant|label|GRF|scratch|spill sends|loads/trip|load B/trip|dpas/trip|loop instr|SBID waits|loads before 1st wait|int-alu|sync
split (128 GRF, 16 tok/thread)|submit<0,8,2,1,true,2,false>|128|False|0|10|2560|8|35|4|5|7|3
lgrf (256 GRF, 32 tok/thread)|submit<0,8,4,1,true,2,true>|256|False|0|18|4608|16|55|9|9|7|7
rb2 (256 GRF, 2 row blocks x 16 tok)|submit<0,8,2,1,true,2,true,2>|256|False|0|12|3072|16|49|5|6|9|4
rb2s (128 GRF, 2 row blocks x 16 tok)|submit<0,8,2,1,true,2,false,2>|128|False|0|12|3072|16|51|7|6|9|6
pd2 (128 GRF, distance 2, 16 tok)|submit<0,8,2,1,true,3,false,1>|128|False|0|20|5120|16|59|9|5|12|7
pd2l (256 GRF, distance 2, 32 tok)|submit<0,8,4,1,true,3,true,1>|256|False|0|36|9216|32|94|14|1|12|10
