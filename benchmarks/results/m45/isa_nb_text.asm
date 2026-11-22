L0:
(W)     mov (16|M0)              r127.0<1>:ud  0x0:ud                              {A@1}
(W)     and (1|M0)               r127.2<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud             
(W)     and (1|M0)               r127.0<1>:uw  r0.4<0;1,0>:uw    0xFF:uw             
(W)     add (1|M0)               r127.2<1>:ud  r127.2<0;1,0>:ud  0x80:ud              {I@2}
(W)     mad (1|M0)               r127.0<1>:ud  r127.2<0;0>:ud    r127.0<0;0>:uw    0x40:uw              {I@1}
(W)     send.ugm (1|M0)          r1       r127  null:0  0xFF000000            0x6219D500           {A@1,$0} // wr:1+0, rd:1; load.ugm.d32x16t.a32.ca.cc.bti[255]
        nop                    
        nop                    
(W)     and (1|M0)               r127.0<1>:ud  r0.0<0;1,0>:ud    0xFFFFFFC0:ud              {$0.src}
(W)     send.ugm (1|M0)          r2       r127  null:0  0xFF000000            0x6229E500           {A@1,$1} // wr:1+0, rd:2; load.ugm.d32x32t.a32.ca.cc.bti[255]
(W)     mov (16|M0)              r106.0<1>:ud  r0.0<1;1,0>:ud                  
        and (1|M0)               cr0.0<1>:ud   cr0.0<0;1,0>:ud   -1073743089:d               {A@1}
        or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   1073743040:d               {A@1}
        mov (1|M0)               r8.0<1>:d     r0.1<0;1,0>:ud                   {A@1}
        mov (1|M0)               r2.2<1>:q     r2.3<0;1,0>:q                    {$1.dst}
(W)     mul (1|M0)               acc0.0<1>:d   r8.0<0;1,0>:d     r2.0<0;1,0>:uw   {I@2}
        macl (1|M0)              r8.0<1>:d     r8.0<0;1,0>:d     r2.0<0;1,0>:d    {Compacted}
        add (1|M0)               r8.0<1>:d     r8.0<0;1,0>:d     r1.0<0;1,0>:uw   {@1,$0.dst}
(W)     mul (1|M0)               acc0.0<1>:ud  r8.0<0;1,0>:ud    0x8E39:uw              {I@1}
        mach (1|M0)              r8.0<1>:ud    r8.0<0;1,0>:ud    0x38E38E39:ud             
        shr (1|M0)               r8.0<1>:ud    r8.0<0;1,0>:ud    0x1:uw              {Compacted,I@1}
        mov (1|M0)               r5.1<1>:q     r8.0<0;1,0>:ud                   {I@1}
        sync.allrd                           null                             {A@1}
        sync.allwr                           null                            
(W)     call (32|M0)             r2.0          L9304                                 {A@1}
L384:
        mul (1|M0)               acc0.0<1>:ud  r41.0<0;1,0>:ud   r2.12<0;1,0>:uw 
        mach (1|M0)              r5.0<1>:ud    r41.0<0;1,0>:ud   r2.6<0;1,0>:ud   {Compacted}
        cmp (1|M0)    (eq)f3.0   null<1>:w     r1.0<0;1,0>:w     0:w              
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r41.0<0;1,0>:d    r2.14<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r41.0<0;1,0>:d    r2.7<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r41.1<0;1,0>:d    r2.12<0;1,0>:uw 
        macl (1|M0)              r7.0<1>:d     r41.1<0;1,0>:d    r2.6<0;1,0>:d    {Compacted}
        mov (1|M0)               r41.2<1>:d    r4.0<0;1,0>:d                    {I@5}
        add3 (1|M0)              r41.3<1>:d    r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d        {I@2}
        add (1|M0)               r41.1<1>:q    r8.0<0;1,0>:ud    -r41.1<0;1,0>:q  {I@1}
(W&f3.0) jmpi                                L6960                                
L544:
        shl (1|M0)               r41.0<1>:q    r41.0<0;1,0>:q    3:w              
        add (1|M0)               r1.2<1>:d     r1.0<0;1,0>:uw    -1:w              
        shl (1|M0)               r2.2<1>:q     r3.1<0;1,0>:q     8:w              
        add (1|M0)               r41.0<1>:q    r41.0<0;1,0>:q    r1.2<0;1,0>:ud   {I@2}
        cmp (1|M0)    (eq)f2.1   null<1>:d     r2.14<0;1,0>:d    0:w              
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r41.0<0;1,0>:uw  {I@2}
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r41.0<0;1,0>:ud  {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r41.2<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r41.1<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r41.0<0;1,0>:uw 
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r41.0<0;1,0>:d  
        mov (1|M0)               r6.2<1>:d     r4.0<0;1,0>:d                    {Compacted,I@5}
        add3 (1|M0)              r6.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d        {I@2}
        add (1|M0)               r92.0<1>:q    r3.0<0;1,0>:q     r6.1<0;1,0>:q    {Compacted,I@1}
        send.ugm (1|M0)          r88      r92  null:0  0x0            0x0240F580           {I@1,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r82      r92  null:0  0x100000            0x0240F580           {$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
(W&f2.1) jmpi                                L2360                                
L800:
        cmp (1|M0)    (eq)f1.1   null<1>:d     r2.14<0;1,0>:d    1:w              
        mov (1|M0)               r41.2<1>:q    r2.14<0;1,0>:ud                 
(W&f1.1) jmpi                                L880                                
L848:
        send.ugm (1|M0)          r74      r92  null:0  0x200000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r78      r92  null:0  0x300000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
L880:
        mov (16|M0)              r4.0<1>:f     0x8018001:f                              
        send.gtwy (1|M0)         null     r4  null:0  0x0            0x02000004           {F@1,$6} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             1:w                              
        mov (1|M0)               r5.0<1>:d     0:w                               {Compacted}
        mov (1|M0)               r14.0<1>:d    512:w                               {Compacted}
        send.slm (1|M0)          r6       r5  null:0  0x0            0x0280F700           {I@2,$7} // wr:1+0, rd:8; load.slm.d64x64t.a32
        send.slm (1|M0)          r15      r14  null:0  0x0            0x0280F700           {I@1,$8} // wr:1+0, rd:8; load.slm.d64x64t.a32
        mov (1|M0)               r23.0<1>:d    1024:w                               {Compacted}
        mov (1|M0)               r24.0<1>:d    1536:w                               {Compacted}
        send.slm (1|M0)          r25      r23  null:0  0x0            0x0280F700           {I@2,$9} // wr:1+0, rd:8; load.slm.d64x64t.a32
        send.slm (1|M0)          r33      r24  null:0  0x0            0x0280F700           {I@1,$10} // wr:1+0, rd:8; load.slm.d64x64t.a32
        cmp (1|M0)    (gt)f2.0   null<1>:ud    r2.14<0;1,0>:ud   0x4:uw             
        sync.allwr                           ($7,$8)                
        dpas.8x8 (16|M0)         r42:d         null:d            r88:s4            r6.0:b           {Atomic,$2.dst}
        dpas.8x8 (16|M0)         r50:d         null:d            r88:s4            r10.0:b          {Atomic}
        dpas.8x8 (16|M0)         r58:d         null:d            r88:s4            r15.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r66:d         null:d            r88:s4            r19.0:ub         {$2}
        sync.allwr                           ($2,$9,$10)                
        dpas.8x8 (16|M0)         r42:d         r42:d             r82:s4            r25.0:b          {Atomic,$3.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r82:s4            r29.0:b          {Atomic}
        dpas.8x8 (16|M0)         r58:d         r58:d             r82:s4            r33.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r82:s4            r37.0:ub         {$3}
(W&~f2.0) jmpi                               L1296                                
L1216:
        sync.nop                             null                             {Compacted,$6.src}
(W)     send.slm (1|M0)          r4       r106  null:0  0x0            0x0210001F           {$11} // wr:1+0, rd:1; fence.slm.none.group
        mov (16|M0)              r5.0<1>:f     0x1084005:f                              
(W)     mov (8|M0)               null<1>:ud    r4.0<1;1,0>:ud                   {Compacted,$11.dst}
        send.gtwy (1|M0)         null     r5  null:0  0x0            0x02000004           {F@1,$12} // wr:1+0, rd:0; signal barrier
(W)     jmpi                                 L1312                                
L1296:
(W&f1.1) jmpi                                L2488                                
L1312:
        mov (1|M0)               r41.5<1>:q    1:w                              
        mov (1|M0)               r41.8<1>:d    1:w                              
L1344:
        and (1|M0)               r41.6<1>:d    r41.10<0;1,0>:d   3:w               {I@2}
        add (1|M0)               r41.5<1>:q    r41.5<0;1,0>:q    1:w              
(W)     mov (1|M0)               r1.3<1>:hf    0x1:hf                             
        cmp (1|M0)    (eq)f2.1   null<1>:d     r41.11<0;1,0>:d   r41.5<0;1,0>:d   {I@1}
        cmp (1|M0)    (lt)f0.0   null<1>:ud    r41.10<0;1,0>:ud  r41.4<0;1,0>:ud 
        cmp (1|M0)    (lt)f3.0   null<1>:ud    r41.11<0;1,0>:ud  r41.5<0;1,0>:ud 
        add (1|M0)               r41.7<1>:d    r41.8<0;1,0>:d    1:w              
(f2.1)  sel (1|M0)               r1.4<1>:uw    r1.3<0;1,0>:uw    0x0:uw              {F@1}
(f0.0)  sel (1|M0)               r1.5<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
(f3.0)  sel (1|M0)               r2.7<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        and (1|M0)    (ne)f1.1   null<1>:uw    r1.4<0;1,0>:uw    r1.5<0;1,0>:uw   {I@2}
(f1.1)  sel (1|M0)               r2.6<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        or (1|M0)     (ne)f1.0   null<1>:uw    r2.6<0;1,0>:uw    r2.7<0;1,0>:uw   {I@1}
(W&f1.0) jmpi                                L1624                                
L1568:
        mov (32|M0)              r86.0<1>:f    r78.0<1;1,0>:f                   {Compacted,$5.dst}
        mov (32|M0)              r88.0<1>:f    r80.0<1;1,0>:f                   {Compacted}
        sync.nop                             null                             {Compacted,$3.src}
        mov (32|M0)              r82.0<1>:d    r74.0<1;1,0>:d                   {Compacted,$4.dst}
        mov (32|M0)              r84.0<1>:d    r76.0<1;1,0>:d                   {Compacted}
(W)     jmpi                                 L1696                                
L1624:
        shl (1|M0)               r1.1<1>:q     r41.5<0;1,0>:q    9:w              
        add (1|M0)               r4.0<1>:q     r92.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,@1,$6.src}
        sync.nop                             null                             {$3.src}
        send.ugm (1|M0)          r82      r4  null:0  0x0            0x0240F580           {I@1,$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r86      r4  null:0  0x100000            0x0240F580           {F@1,$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
L1696:
        add (1|M0)               r1.6<2>:b     r41.24<0;1,0>:b   1:w              
        add (1|M0)               r1.2<1>:d     r1.6<0;1,0>:ub    134316032:d               {I@1}
        sync.nop                             null                             {Compacted,$0.src}
        mov (16|M0)              r4.0<1>:d     r1.2<0;1,0>:d                    {Compacted,@1,$6.src}
        send.gtwy (1|M0)         null     r4  null:0  0x0            0x02000004           {I@1,$1} // wr:1+0, rd:0; signal barrier
(W)     mov (1|M0)               f2.0<1>:uw    r1.6<0;1,0>:b                   
(W)     sync.bar                             f2.0:uw                         
        sync.nop                             null                             {Compacted,$13.src}
        shl (1|M0)               r5.0<1>:d     r41.6<0;1,0>:d    11:w               {Compacted,$12.src}
        add (1|M0)               r41.8<1>:d    r41.8<0;1,0>:d    4:w              
        or (1|M0)                r6.0<1>:ud    r5.0<0;1,0>:ud    0x200:uw              {I@2}
        send.slm (1|M0)          r7       r5  null:0  0x0            0x0280F700           {$7} // wr:1+0, rd:8; load.slm.d64x64t.a32
        send.slm (1|M0)          r15      r6  null:0  0x0            0x0280F700           {I@1,$8} // wr:1+0, rd:8; load.slm.d64x64t.a32
        or (1|M0)                r4.0<1>:ud    r5.0<0;1,0>:ud    0x400:uw              {Compacted,$1.src}
        or (1|M0)                r31.0<1>:ud   r5.0<0;1,0>:ud    0x600:uw              {Compacted}
        send.slm (1|M0)          r23      r4  null:0  0x0            0x0280F700           {I@2,$9} // wr:1+0, rd:8; load.slm.d64x64t.a32
        send.slm (1|M0)          r33      r31  null:0  0x0            0x0280F700           {I@1,$10} // wr:1+0, rd:8; load.slm.d64x64t.a32
        cmp (1|M0)    (lt)f0.1   null<1>:ud    r41.8<0;1,0>:ud   r2.14<0;1,0>:ud 
        sync.allwr                           ($3,$7,$8,$14)                
        dpas.8x8 (16|M0)         r42:d         r42:d             r74:s4            r7.0:b           {Atomic,$4.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r74:s4            r11.0:b          {Atomic}
        dpas.8x8 (16|M0)         r58:d         r58:d             r74:s4            r15.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r74:s4            r19.0:ub         {$3}
        sync.allwr                           ($3,$9,$10)                
        dpas.8x8 (16|M0)         r42:d         r42:d             r78:s4            r23.0:b          {Atomic,$5.dst}
        dpas.8x8 (16|M0)         r50:d         r50:d             r78:s4            r27.0:b          {Atomic}
        dpas.8x8 (16|M0)         r58:d         r58:d             r78:s4            r33.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r66:d         r66:d             r78:s4            r37.0:ub         {$14}
(W&~f0.1) jmpi                               L2192                                
L2112:
(W)     send.slm (1|M0)          r4       r106  null:0  0x0            0x0210001F           {$11} // wr:1+0, rd:1; fence.slm.none.group
        add (1|M0)               r1.6<2>:b     r41.24<0;1,0>:b   5:w              
        add (1|M0)               r2.3<1>:d     r1.6<0;1,0>:ub    17317888:d               {I@1}
        mov (16|M0)              r5.0<1>:d     r2.3<0;1,0>:d                    {Compacted,I@1}
(W)     mov (8|M0)               null<1>:ud    r4.0<1;1,0>:ud                   {Compacted,$11.dst}
        send.gtwy (1|M0)         null     r5  null:0  0x0            0x02000004           {I@2,$13} // wr:1+0, rd:0; signal barrier
L2192:
        cmp (1|M0)    (eq)f3.1   null<1>:d     r41.10<0;1,0>:d   r41.4<0;1,0>:d  
(W)     mov (1|M0)               r1.3<1>:hf    0x1:hf                             
(f2.1)  sel (1|M0)               r2.6<1>:uw    r1.3<0;1,0>:uw    0x0:uw              {F@1}
(f3.1)  sel (1|M0)               r1.4<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        and (1|M0)    (ne)f0.0   null<1>:uw    r1.4<0;1,0>:uw    r2.6<0;1,0>:uw   {I@1}
(W&f0.0) jmpi                                L2488                                
L2288:
        sync.nop                             null                             {Compacted,$14.src}
        mov (32|M0)              r78.0<1>:f    r86.0<1;1,0>:f                   {Compacted,$0.dst}
        mov (32|M0)              r80.0<1>:f    r88.0<1;1,0>:f                   {Compacted}
        mov (32|M0)              r74.0<1>:d    r82.0<1;1,0>:d                   {Compacted,$15.dst}
        mov (32|M0)              r76.0<1>:d    r84.0<1;1,0>:d                   {Compacted}
        mov (1|M0)               r41.8<1>:d    r41.7<0;1,0>:d                  
(W)     jmpi                                 L1344                                
L2360:
        mov (32|M0)              r50.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r52.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r54.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r56.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r42.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r44.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r46.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r48.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r66.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r68.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r70.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r72.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r58.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r60.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r62.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r64.0<1>:d    0:w                               {Compacted}
L2488:
        shl (1|M0)               r41.0<1>:q    r41.0<0;1,0>:q    4:w               {Compacted}
        shl (1|M0)               r41.1<1>:q    r41.1<0;1,0>:q    4:w              
        shl (1|M0)               r41.0<1>:q    r41.0<0;1,0>:q    2:w               {Compacted,I@2}
        shl (1|M0)               r41.2<1>:q    r41.1<0;1,0>:q    2:w               {I@2}
        add (1|M0)               r4.0<1>:q     r3.2<0;1,0>:q     r41.0<0;1,0>:q   {Compacted,@2,$6.src}
        add (1|M0)               r5.0<1>:q     r3.3<0;1,0>:q     r41.2<0;1,0>:q   {@2,$13.src}
        send.ugm (1|M0)          r93      r4  null:0  0x0            0x0210D580           {I@2,$12} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        send.ugm (1|M0)          r94      r5  null:0  0x0            0x0210D580           {I@1,$13} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        cmp (1|M0)    (eq)f0.1   null<1>:d     r3.9<0;1,0>:d     0:w              
(f0.1)  cmp (1|M0)    (eq)f0.1   null<1>:d     r3.8<0;1,0>:d     0:w              
(W&f0.1) jmpi                                L2680                                
L2640:
        add (1|M0)               r4.0<1>:q     r3.4<0;1,0>:q     r41.2<0;1,0>:q   {Compacted,$12.src}
        send.ugm (1|M0)          r95      r4  null:0  0x0            0x0210D580           {I@1,$1} // wr:1+0, rd:1; load.ugm.d32x16t.a64
(W)     jmpi                                 L2688                                
L2680:
        mov (16|M0)              r95.0<1>:f    0.0:f                               {Compacted}
L2688:
        cmp (1|M0)    (eq)f0.0   null<1>:d     r3.11<0;1,0>:d    0:w              
(f0.0)  cmp (1|M0)    (eq)f0.0   null<1>:d     r3.10<0;1,0>:d    0:w              
(W&f0.0) jmpi                                L2784                                
L2736:
        sync.nop                             null                             {Compacted,$1.src}
        add (1|M0)               r4.0<1>:q     r3.5<0;1,0>:q     r41.0<0;1,0>:q   {Compacted,$12.src}
        send.ugm (1|M0)          r97      r4  null:0  0x0            0x0210D580           {I@1,$6} // wr:1+0, rd:1; load.ugm.d32x16t.a64
(W)     jmpi                                 L2792                                
L2784:
        mov (16|M0)              r97.0<1>:f    0.0:f                               {Compacted}
L2792:
        sync.nop                             null                             {Compacted,$14.dst}
        sync.nop                             null                             {$13.src}
        mov (16|M0)              r5.0<1>:f     r42.0<1;1,0>:d                   {$3.dst}
        mov (1|M0)               r2.3<1>:f     256.0:f                              
        sync.allrd                           ($1,$6)                
        mov (16|M0)              r4.0<1>:f     r58.0<1;1,0>:d                   {$12.src}
        mad (16|M0)              acc0.0<1>:f   r4.0<1;0>:f       r5.0<1;0>:f       r2.3<0>:f        {Compacted,F@1}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.0<0;1,0>:f   {Compacted,$1.dst}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted,$12.dst}
        sync.nop                             null                             {Compacted,$6.dst}
        mad (16|M0)              r6.0<1>:f     r97.0<1;0>:f      acc0.0<1;0>:f     r94.0<0>:f       {Compacted,$13.dst}
        mul (1|M0)               acc0.0<1>:ud  r41.2<0;1,0>:ud   r3.28<0;1,0>:uw  {F@1}
        mach (1|M0)              r9.0<1>:ud    r41.2<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        mov (16|M0)              r11.0<1>:f    r43.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r59.0<1;1,0>:d                  
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r41.2<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r10.0<1>:d    r41.2<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r41.3<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r5.0<1>:w     0x1010101:v                              
        macl (1|M0)              r7.0<1>:d     r41.3<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        mov (1|M0)               r1.2<1>:d     r8.0<0;1,0>:d                   
        or (2|M0)                r2.4<1>:d     r41.2<1;1,0>:d    r5.0<1;1,0>:w   
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r9.0<0;0>:d       r10.0<0>:d      
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.1<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        add (1|M0)               r41.0<1>:q    r3.6<0;1,0>:q     r41.0<0;1,0>:q  
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mad (16|M0)              r13.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.1<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {F@1}
        mach (1|M0)              r9.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        add (1|M0)               r4.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {I@3}
        mov (16|M0)              r11.0<1>:f    r44.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r60.0<1;1,0>:d                  
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        send.ugm (1|M0)          null     r4  r6:1  0x0            0x0200D584           {I@3,$7} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        macl (1|M0)              r4.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d   {$7.src}
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        mov (2|M0)               r7.0<1>:w     0x2020202:v                              
        macl (1|M0)              r5.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        mov (1|M0)               r1.2<1>:d     r8.0<0;1,0>:d                    {Compacted}
        or (2|M0)                r10.0<1>:d    r41.2<1;1,0>:d    r7.0<1;1,0>:w   
        add3 (1|M0)              r1.3<1>:d     r5.0<0;0>:d       r9.0<0;0>:d       r4.0<0>:d       
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.2<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@1}
        mad (16|M0)              r14.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.2<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r10.0<0;1,0>:ud   r3.28<0;1,0>:uw  {F@1}
        mach (1|M0)              r5.0<1>:ud    r10.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        add (1|M0)               r6.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@3}
        mov (16|M0)              r11.0<1>:f    r45.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r61.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r10.0<0;1,0>:d    r3.30<0;1,0>:uw 
        send.ugm (1|M0)          null     r6  r13:1  0x0            0x0200D584           {I@3,$8} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        macl (1|M0)              r6.0<1>:d     r10.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted,$8.src}
(W)     mul (1|M0)               acc0.0<1>:d   r10.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0x3030303:v                              
        macl (1|M0)              r7.0<1>:d     r10.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r41.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.3<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r10.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.3<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r13.0<1>:f    r46.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r62.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0x4040404:v                              
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r11.0<1>:d    r41.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.4<0;1,0>:f   {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$9} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.4<0>:f       {Compacted,$9.src}
        mul (1|M0)               acc0.0<1>:ud  r11.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r11.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r10:1  0x0            0x0200D584           {I@2,$10} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r13.0<1>:f    r47.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r10.0<1>:f    r63.0<1;1,0>:d                   {$10.src}
(W)     mul (1|M0)               acc0.0<1>:d   r11.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r11.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r11.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0x5050505:v                              
        macl (1|M0)              r7.0<1>:d     r11.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r10.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r41.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.5<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r11.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.5<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r12.0<1>:f    r64.0<1;1,0>:d                  
        mov (16|M0)              r13.0<1>:f    r48.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0x6060606:v                              
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r10.0<1>:d    r41.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.6<0;1,0>:f   {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$11} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.6<0>:f       {Compacted,$11.src}
        mul (1|M0)               acc0.0<1>:ud  r10.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r10.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r11:1  0x0            0x0200D584           {I@2,$12} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r12.0<1>:f    r65.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r11.0<1>:f    r49.0<1;1,0>:d                   {$12.src}
(W)     mul (1|M0)               acc0.0<1>:d   r10.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r10.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r10.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0x7070707:v                              
        macl (1|M0)              r7.0<1>:d     r10.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r41.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.7<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r10.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.7<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r13.0<1>:f    r50.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r66.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0x8080808:uv                             
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r11.0<1>:d    r41.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.8<0;1,0>:f   {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$13} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.8<0>:f       {Compacted,$13.src}
        mul (1|M0)               acc0.0<1>:ud  r11.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r11.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r10:1  0x0            0x0200D584           {I@2,$14} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r13.0<1>:f    r51.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r10.0<1>:f    r67.0<1;1,0>:d                   {$14.src}
(W)     mul (1|M0)               acc0.0<1>:d   r11.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r11.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r11.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0x9090909:uv                             
        macl (1|M0)              r7.0<1>:d     r11.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r10.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r41.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.9<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r11.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.9<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r12.0<1>:f    r68.0<1;1,0>:d                  
        mov (16|M0)              r13.0<1>:f    r52.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0xA0A0A0A:uv                             
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r10.0<1>:d    r41.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.10<0;1,0>:f  {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$1} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.10<0>:f      {Compacted,$1.src}
        mul (1|M0)               acc0.0<1>:ud  r10.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r10.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r11:1  0x0            0x0200D584           {I@2,$6} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r12.0<1>:f    r69.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r11.0<1>:f    r53.0<1;1,0>:d                   {$6.src}
(W)     mul (1|M0)               acc0.0<1>:d   r10.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r10.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r10.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0xB0B0B0B:uv                             
        macl (1|M0)              r7.0<1>:d     r10.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r41.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.11<0;1,0>:f  {Compacted}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r10.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.11<0>:f      {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r13.0<1>:f    r54.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r70.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0xC0C0C0C:uv                             
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                   
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r11.0<1>:d    r41.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.12<0;1,0>:f 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$7} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.12<0>:f      {Compacted,$7.src}
        mul (1|M0)               acc0.0<1>:ud  r11.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r11.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r10:1  0x0            0x0200D584           {I@2,$8} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r13.0<1>:f    r55.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r10.0<1>:f    r71.0<1;1,0>:d                   {$8.src}
(W)     mul (1|M0)               acc0.0<1>:d   r11.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r11.0<0;1,0>:d    r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r11.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0xD0D0D0D:uv                             
        macl (1|M0)              r7.0<1>:d     r11.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r10.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r41.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.13<0;1,0>:f 
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r11.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.13<0>:f      {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r12.0<1>:f    r72.0<1;1,0>:d                  
        mov (16|M0)              r13.0<1>:f    r56.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0xE0E0E0E:uv                             
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r10.0<1>:d    r41.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.14<0;1,0>:f  {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$9} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r97.0<1;0>:f      acc0.0<1;0>:f     r94.14<0>:f      {Compacted,$9.src}
        mul (1|M0)               acc0.0<1>:ud  r10.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r10.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r11:1  0x0            0x0200D584           {I@2,$10} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r12.0<1>:f    r73.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r11.0<1>:f    r57.0<1;1,0>:d                   {$10.src}
(W)     mul (1|M0)               acc0.0<1>:d   r10.0<0;1,0>:d    r3.30<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0xF0F0F0F:uv                             
        macl (1|M0)              r6.0<1>:d     r10.0<0;1,0>:d    r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r10.1<0;1,0>:d    r3.28<0;1,0>:uw 
        macl (1|M0)              r7.0<1>:d     r10.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r41.2<1>:d    r41.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r95.15<0;1,0>:f  {Compacted}
        mul (16|M0)              r93.0<1>:f    r93.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r41.2<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r41.2<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r41.2<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r41.2<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r41.3<0;1,0>:d    r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r41.3<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d        {I@3}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {I@3,$11} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@1}
        mad (16|M0)              r10.0<1>:f    r97.0<1;0>:f      r93.0<1;0>:f      r94.15<0>:f      {Compacted}
        add (1|M0)               r8.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,@1,$11.src}
        send.ugm (1|M0)          null     r8  r10:1  0x0            0x0200D584           {A@1,$12} // wr:1+1, rd:0; store.ugm.d32x16t.a64
(W)     jmpi                                 L9280                                
L6960:
        shl (1|M0)               r41.1<1>:q    r41.1<0;1,0>:q    7:w              
        shl (1|M0)               r1.1<1>:q     r2.6<0;1,0>:q     2:w              
        shl (1|M0)               r41.1<1>:q    r41.1<0;1,0>:q    2:w               {I@2}
        cmp (1|M0)    (eq)f3.1   null<1>:d     r2.14<0;1,0>:d    0:w              
        add (1|M0)               r3.0<1>:q     r2.4<0;1,0>:q     r41.1<0;1,0>:q   {Compacted,I@2}
        add (1|M0)               r11.0<1>:q    r2.5<0;1,0>:q     r41.1<0;1,0>:q   {Compacted}
        add (1|M0)               r4.0<1>:q     r3.0<0;1,0>:q     r1.1<0;1,0>:q    {Compacted,I@2}
        add (1|M0)               r5.0<1>:q     r11.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        send.ugm (1|M0)          r107     r3  null:0  0x0            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r111     r3  null:0  0x100000            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r90      r11  null:0  0x0            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r94      r11  null:0  0x100000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r115     r4  null:0  0x0            0x0240F580           {I@2,$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r119     r4  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r98      r5  null:0  0x0            0x0240F580           {I@1,$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r102     r5  null:0  0x100000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
(W&f3.1) jmpi                                L9280                                
L7200:
        mov (1|M0)               r3.2<1>:d     0:w                               {$14.src}
L7216:
        or (1|M0)                r3.3<1>:d     r3.2<0;1,0>:d     1:w               {I@1}
        and (1|M0)               r3.4<1>:d     r3.2<0;1,0>:d     2:w              
        cmp (1|M0)    (lt)f3.0   null<1>:ud    r3.3<0;1,0>:ud    r2.14<0;1,0>:ud  {I@2}
(W&~f3.0) jmpi                               L7824                                
L7280:
        shl (1|M0)               r1.1<1>:q     r3.3<0;1,0>:ud    1:w              
        mov (2|M0)               r10.0<1>:w    0x1010101:v                              
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r2.24<0;1,0>:uw  {I@2}
        sync.nop                             null                             {Compacted,$13.src}
        mach (1|M0)              r5.0<1>:ud    r1.2<0;1,0>:ud    r2.12<0;1,0>:ud  {$4.src}
        sync.nop                             null                             {Compacted,$12.src}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {$8.src}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r2.26<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r1.2<0;1,0>:d     r2.13<0;1,0>:d   {$14.src}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r2.24<0;1,0>:uw 
        macl (1|M0)              r7.0<1>:d     r1.3<0;1,0>:d     r2.12<0;1,0>:d   {$1.src}
        or (2|M0)                r1.2<1>:d     r1.2<1;1,0>:d     r10.0<1;1,0>:w   {I@7}
        mov (1|M0)               r1.4<1>:d     r4.0<0;1,0>:d                    {I@6}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r2.26<0;1,0>:uw  {I@2}
        macl (1|M0)              r12.0<1>:d    r1.2<0;1,0>:d     r2.13<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r2.24<0;1,0>:uw 
        macl (1|M0)              r4.0<1>:d     r1.3<0;1,0>:d     r2.12<0;1,0>:d  
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r2.24<0;1,0>:uw 
        add3 (1|M0)              r1.5<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r7.0<1>:ud    r1.2<0;1,0>:ud    r2.12<0;1,0>:ud 
        shl (1|M0)               r1.2<1>:q     r1.2<0;1,0>:q     2:w               {I@2}
        mov (1|M0)               r6.0<1>:ud    acc0.0<0;1,0>:ud                
        add3 (1|M0)              r2.5<1>:d     r4.0<0;0>:d       r7.0<0;0>:d       r12.0<0>:d       {I@3}
        mov (1|M0)               r2.4<1>:d     r6.0<0;1,0>:d                    {Compacted,I@2}
        add (1|M0)               r8.0<1>:q     r3.0<0;1,0>:q     r1.2<0;1,0>:q    {Compacted}
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@2}
        send.ugm (1|M0)          r29      r8  null:0  0x0            0x0240F580           {I@2,$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r33      r8  null:0  0x100000            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r9.0<1>:q     r11.0<0;1,0>:q    r1.2<0;1,0>:q    {Compacted}
        add (1|M0)               r5.0<1>:q     r3.0<0;1,0>:q     r2.2<0;1,0>:q    {Compacted,I@2}
        add (1|M0)               r8.0<1>:q     r11.0<0;1,0>:q    r2.2<0;1,0>:q    {$0.src}
        send.ugm (1|M0)          r13      r9  null:0  0x0            0x0240F580           {I@3,$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r17      r9  null:0  0x100000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r37      r5  null:0  0x0            0x0240F580           {I@2,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r41      r5  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r21      r8  null:0  0x0            0x0240F580           {I@1,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r25      r8  null:0  0x100000            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
L7824:
        cmp (1|M0)    (gt)f2.1   null<1>:ud    r3.2<0;1,0>:ud    0x3:uw             
(W&f2.1) jmpi                                L7888                                
L7856:
        mov (1|M0)               r2.0<2>:b     r3.8<0;1,0>:b                   
(W)     jmpi                                 L8000                                
L7888:
        or (1|M0)                r1.6<2>:b     r3.16<0;1,0>:b    5:w              
        mov (1|M0)               r2.0<2>:b     r3.16<0;1,0>:b                   {I@3}
        add (1|M0)               r1.2<1>:d     r1.6<0;1,0>:ub    17334272:d               {I@2}
        sync.nop                             null                             {Compacted,$12.src}
        mov (16|M0)              r4.0<1>:d     r1.2<0;1,0>:d                    {Compacted,@1,$8.src}
        send.gtwy (1|M0)         null     r4  null:0  0x0            0x02000004           {I@1,$14} // wr:1+0, rd:0; signal barrier
(W)     mov (1|M0)               f1.0<1>:uw    r1.6<0;1,0>:b                   
(W)     sync.bar                             f1.0:uw                         
L8000:
        sync.allrd                           ($12,$14)                
        shl (1|M0)               r4.0<1>:d     r3.4<0;1,0>:d     11:w               {Compacted,$8.src}
        sync.allrd                           ($5,$13)                
        or (1|M0)                r5.0<1>:ud    r4.0<0;1,0>:ud    0x200:uw              {Compacted,@1,$4.src}
        or (1|M0)                r6.0<1>:ud    r4.0<0;1,0>:ud    0x400:uw              {Compacted}
        or (1|M0)                r7.0<1>:ud    r4.0<0;1,0>:ud    0x600:uw              {Compacted,$1.src}
        sync.allwr                           ($5,$13,$14)                
        send.slm (1|M0)          null     r4  r107:8  0x0            0x0200F704           {$10} // wr:1+8, rd:0; store.slm.d64x64t.a32
        sync.allwr                           ($1,$2,$4)                
        send.slm (1|M0)          null     r5  r90:8  0x0            0x0200F704           {I@3,$6} // wr:1+8, rd:0; store.slm.d64x64t.a32
        sync.allwr                           ($0,$8,$15)                
        send.slm (1|M0)          null     r6  r115:8  0x0            0x0200F704           {I@2,$7} // wr:1+8, rd:0; store.slm.d64x64t.a32
        sync.allwr                           ($3,$11)                
        send.slm (1|M0)          null     r7  r98:8  0x0            0x0200F704           {I@1,$9} // wr:1+8, rd:0; store.slm.d64x64t.a32
(W)     send.slm (1|M0)          r8       r106  null:0  0x0            0x0210001F           {$8} // wr:1+0, rd:1; fence.slm.none.group
        or (1|M0)                r2.0<2>:b     r2.0<0;1,0>:b     1:w              
        add (1|M0)               r1.2<1>:d     r2.0<0;1,0>:ub    134299648:d               {I@1}
        mov (16|M0)              r9.0<1>:d     r1.2<0;1,0>:d                    {Compacted,I@1}
(W)     mov (8|M0)               null<1>:ud    r8.0<1;1,0>:ud                   {Compacted,$8.dst}
        send.gtwy (1|M0)         null     r9  null:0  0x0            0x02000004           {I@2,$1} // wr:1+0, rd:0; signal barrier
        add (1|M0)               r3.2<1>:ud    r3.2<0;1,0>:ud    0x2:uw             
        and (1|M0)               r3.4<1>:ud    r3.3<0;1,0>:ud    0x3:uw             
        cmp (1|M0)    (lt)f2.0   null<1>:ud    r3.2<0;1,0>:ud    r2.14<0;1,0>:ud  {I@2}
(W&~f2.0) jmpi                               L8864                                
L8336:
        shl (1|M0)               r1.1<1>:q     r3.2<0;1,0>:ud    1:w              
        mov (2|M0)               r10.0<1>:w    0x1010101:v                              
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r2.24<0;1,0>:uw  {I@2}
        mach (1|M0)              r5.0<1>:ud    r1.2<0;1,0>:ud    r2.12<0;1,0>:ud  {$6.src}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {$10.src}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r2.26<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r1.2<0;1,0>:d     r2.13<0;1,0>:d   {$7.src}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r2.24<0;1,0>:uw 
        macl (1|M0)              r7.0<1>:d     r1.3<0;1,0>:d     r2.12<0;1,0>:d   {$9.src}
        or (2|M0)                r1.2<1>:d     r1.2<1;1,0>:d     r10.0<1;1,0>:w   {I@7}
        mov (1|M0)               r1.4<1>:d     r4.0<0;1,0>:d                    {I@6}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r2.26<0;1,0>:uw  {I@2}
        macl (1|M0)              r12.0<1>:d    r1.2<0;1,0>:d     r2.13<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r2.24<0;1,0>:uw 
        macl (1|M0)              r4.0<1>:d     r1.3<0;1,0>:d     r2.12<0;1,0>:d  
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r2.24<0;1,0>:uw 
        add3 (1|M0)              r1.5<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r7.0<1>:ud    r1.2<0;1,0>:ud    r2.12<0;1,0>:ud 
        shl (1|M0)               r1.2<1>:q     r1.2<0;1,0>:q     2:w               {I@2}
        mov (1|M0)               r6.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
        add3 (1|M0)              r2.5<1>:d     r4.0<0;0>:d       r7.0<0;0>:d       r12.0<0>:d       {I@3}
        mov (1|M0)               r2.4<1>:d     r6.0<0;1,0>:d                    {Compacted,I@2}
        add (1|M0)               r8.0<1>:q     r3.0<0;1,0>:q     r1.2<0;1,0>:q   
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@2}
        send.ugm (1|M0)          r107     r8  null:0  0x0            0x0240F580           {I@2,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r111     r8  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r9.0<1>:q     r11.0<0;1,0>:q    r1.2<0;1,0>:q    {Compacted,$1.src}
        add (1|M0)               r5.0<1>:q     r3.0<0;1,0>:q     r2.2<0;1,0>:q    {Compacted,I@2}
        add (1|M0)               r8.0<1>:q     r11.0<0;1,0>:q    r2.2<0;1,0>:q    {$5.src}
        send.ugm (1|M0)          r90      r9  null:0  0x0            0x0240F580           {I@3,$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r94      r9  null:0  0x100000            0x0240F580           {$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r115     r5  null:0  0x0            0x0240F580           {I@2,$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r119     r5  null:0  0x100000            0x0240F580           {$0} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r98      r8  null:0  0x0            0x0240F580           {I@1,$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r102     r8  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
L8864:
(W&f2.1) jmpi                                L8912                                
L8880:
        mov (1|M0)               r2.0<2>:b     r3.12<0;1,0>:b                  
(W)     jmpi                                 L9016                                
L8912:
        add (1|M0)               r1.6<2>:b     r3.16<0;1,0>:b    5:w              
        mov (1|M0)               r2.0<2>:b     r3.16<0;1,0>:b                   {I@3}
        add (1|M0)               r1.2<1>:d     r1.6<0;1,0>:ub    17334272:d               {I@2}
        mov (16|M0)              r4.0<1>:d     r1.2<0;1,0>:d                    {Compacted,@1,$10.src}
        send.gtwy (1|M0)         null     r4  null:0  0x0            0x02000004           {I@1,$6} // wr:1+0, rd:0; signal barrier
(W)     mov (1|M0)               f0.0<1>:uw    r1.6<0;1,0>:b                   
(W)     sync.bar                             f0.0:uw                         
L9016:
        sync.nop                             null                             {Compacted,$6.src}
        shl (1|M0)               r4.0<1>:ud    r3.4<0;1,0>:ud    0xB:uw              {Compacted,$10.src}
        or (1|M0)                r5.0<1>:ud    r4.0<0;1,0>:ud    0x200:uw              {Compacted,@1,$0.src}
        or (1|M0)                r6.0<1>:ud    r4.0<0;1,0>:ud    0x400:uw              {Compacted,$7.src}
        or (1|M0)                r7.0<1>:ud    r4.0<0;1,0>:ud    0x600:uw              {Compacted,$9.src}
        sync.allwr                           ($0,$3)                
        send.slm (1|M0)          null     r4  r29:8  0x0            0x0200F704           {$12} // wr:1+8, rd:0; store.slm.d64x64t.a32
        sync.allwr                           ($2,$15)                
        send.slm (1|M0)          null     r5  r13:8  0x0            0x0200F704           {I@3,$13} // wr:1+8, rd:0; store.slm.d64x64t.a32
        sync.allwr                           ($5,$11)                
        send.slm (1|M0)          null     r6  r37:8  0x0            0x0200F704           {I@2,$14} // wr:1+8, rd:0; store.slm.d64x64t.a32
        sync.allwr                           ($12,$13)                
        send.slm (1|M0)          null     r7  r21:8  0x0            0x0200F704           {I@1,$1} // wr:1+8, rd:0; store.slm.d64x64t.a32
(W)     send.slm (1|M0)          r8       r106  null:0  0x0            0x0210001F           {$7} // wr:1+0, rd:1; fence.slm.none.group
        add (1|M0)               r2.0<2>:b     r2.0<0;1,0>:b     1:w              
        add (1|M0)               r1.2<1>:d     r2.0<0;1,0>:ub    134299648:d               {I@1}
        mov (16|M0)              r9.0<1>:d     r1.2<0;1,0>:d                    {Compacted,@1,$1.src}
(W)     mov (8|M0)               null<1>:ud    r8.0<1;1,0>:ud                   {Compacted,$7.dst}
        send.gtwy (1|M0)         null     r9  null:0  0x0            0x02000004           {I@2,$8} // wr:1+0, rd:0; signal barrier
(W&f2.0) jmpi                                L7216                                
L9280:
(W)     mov (16|M0)              r127.0<1>:f   r106.0<1;1,0>:f                  {Compacted}
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,F@1,$9} // wr:1+0, rd:0; end of thread
L9304:
        mov (2|M0)               r5.0<1>:d     0x1:v                              
        mov (1|M0)               r2.2<1>:d     63:w                               {Compacted}
        mov (1|M0)               r8.2<1>:q     0:w                              
        mov (1|M0)               r8.3<1>:q     0:w                              
L9360:
        mov (1|M0)               r41.0<1>:q    r2.2<0;1,0>:ud                   {I@3}
        shl (1|M0)               r8.2<1>:q     r8.2<0;1,0>:q     1:w               {I@3}
        shr (1|M0)               r4.0<1>:uq    r5.1<0;1,0>:uq    r41.0<0;1,0>:uq  {I@2}
(W)     mov (1|M0)               r1.3<1>:hf    0x1:hf                             
        bfn.0xEA (2|M0)          r4.0<1>:ud    r8.4<1;0>:ud      r4.0<1;0>:ud      r5.0<1>:ud       {I@1} // s0|s1&s2
        cmp (1|M0)    (eq)f2.1   null<1>:d     r2.2<0;1,0>:d     0:w              
        cmp (1|M0)    (lt)f1.0   null<1>:ud    r4.0<0;1,0>:ud    r2.4<0;1,0>:ud   {I@2}
        cmp (1|M0)    (lt)f3.0   null<1>:ud    r4.1<0;1,0>:ud    r2.5<0;1,0>:ud  
        shl (1|M0)               r41.0<1>:uq   r1.3<0;1,0>:uw    r41.0<0;1,0>:uq  {F@1}
        add (1|M0)               r8.2<1>:q     r4.0<0;1,0>:q     -r2.2<0;1,0>:q  
(f1.0)  cmp (1|M0)    (eq)f1.0   null<1>:d     r4.1<0;1,0>:d     r2.5<0;1,0>:d   
(f3.0)  sel (1|M0)               r1.5<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        or (2|M0)                r41.0<1>:d    r41.0<1;1,0>:d    r8.6<1;1,0>:d    {I@4}
(f1.0)  sel (1|M0)               r1.4<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        or (1|M0)     (ne)f3.1   null<1>:uw    r1.4<0;1,0>:uw    r1.5<0;1,0>:uw   {I@1}
        add (1|M0)               r1.2<1>:ud    r2.2<0;1,0>:ud    0xFFFFFFFF:ud             
(f3.1)  mov (1|M0)               r8.4<1>:ud    r4.0<0;1,0>:d                   
(f3.1)  mov (1|M0)               r8.5<1>:ud    r4.1<0;1,0>:d                   
(f3.1)  mov (1|M0)               r41.0<1>:ud   r8.6<0;1,0>:d                   
(f3.1)  mov (1|M0)               r41.1<1>:ud   r8.7<0;1,0>:d                   
(W&f2.1) jmpi                                L9744                                
L9696:
        mov (1|M0)               r2.2<1>:d     r1.2<0;1,0>:d                    {I@6}
        mov (1|M0)               r8.3<1>:q     r41.0<0;1,0>:q                   {I@3}
(W)     jmpi                                 L9360                                
L9744:
        sync.allrd                           null                             {A@1}
        sync.allwr                           null                            
        ret (32|M0)                          r2.0                             {A@1}
L9792:
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
