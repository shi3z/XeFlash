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
(W)     mov (16|M0)              r41.0<1>:ud   r0.0<1;1,0>:ud                  
        and (1|M0)               cr0.0<1>:ud   cr0.0<0;1,0>:ud   -1073743089:d               {A@1}
        or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   1073743040:d               {A@1}
        mul (1|M0)               acc0.0<1>:ud  r2.0<0;1,0>:ud    r0.2<0;1,0>:uw   {A@1,$1.dst}
        mach (1|M0)              r5.0<1>:ud    r2.0<0;1,0>:ud    r0.1<0;1,0>:ud   {Compacted}
        mov (1|M0)               r3.3<1>:d     r1.0<0;1,0>:uw                   {$0.dst}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
        mov (1|M0)               r42.3<1>:d    r5.0<0;1,0>:d                    {I@3}
        mov (1|M0)               r42.2<1>:d    r4.0<0;1,0>:d                    {I@2}
        mov (1|M0)               r42.0<1>:q    r1.0<0;1,0>:uw                  
        add (1|M0)               r42.1<1>:q    r42.1<0;1,0>:q    r1.0<0;1,0>:uw   {I@2}
        mov (1|M0)               r43.3<1>:q    r2.3<0;1,0>:q                   
        shr (1|M0)               r42.1<1>:uq   r42.1<0;1,0>:uq   0x3:uw              {I@2}
        mov (1|M0)               r43.2<1>:q    r42.1<0;1,0>:q                   {I@1}
        sync.allrd                           null                             {A@1}
        sync.allwr                           null                            
(W)     call (32|M0)             r44.2         L8256                                 {A@1}
L416:
        mul (1|M0)               acc0.0<1>:ud  r43.8<0;1,0>:ud   r2.12<0;1,0>:uw 
        mach (1|M0)              r5.0<1>:ud    r43.8<0;1,0>:ud   r2.6<0;1,0>:ud  
        shl (1|M0)               r2.2<1>:q     r2.5<0;1,0>:q     8:w              
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r43.8<0;1,0>:d    r2.14<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r43.8<0;1,0>:d    r2.7<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r43.9<0;1,0>:d    r2.12<0;1,0>:uw 
        macl (1|M0)              r7.0<1>:d     r43.9<0;1,0>:d    r2.6<0;1,0>:d    {Compacted}
        shl (1|M0)               r43.4<1>:q    r43.4<0;1,0>:q    3:w              
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted,I@6}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d        {I@3}
        add (1|M0)               r43.4<1>:q    r43.4<0;1,0>:q    r1.0<0;1,0>:uw   {I@3}
        add (1|M0)               r42.1<1>:q    r42.1<0;1,0>:q    -r1.1<0;1,0>:q   {I@2}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r43.16<0;1,0>:uw {I@2}
        mach (1|M0)              r9.0<1>:ud    r2.4<0;1,0>:ud    r43.8<0;1,0>:ud  {Compacted}
        shl (1|M0)               r1.1<1>:q     r42.1<0;1,0>:q    7:w               {I@3}
        shl (1|M0)               r42.0<1>:q    r42.0<0;1,0>:q    4:w               {Compacted}
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@3}
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r43.18<0;1,0>:uw
        macl (1|M0)              r10.0<1>:d    r2.4<0;1,0>:d     r43.9<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r43.16<0;1,0>:uw
        shl (1|M0)               r42.0<1>:q    r42.0<0;1,0>:q    2:w               {Compacted,I@6}
        add (1|M0)               r1.2<1>:q     r2.6<0;1,0>:q     r1.1<0;1,0>:q    {I@5}
        macl (1|M0)              r11.0<1>:d    r2.5<0;1,0>:d     r43.8<0;1,0>:d  
        add (1|M0)               r1.1<1>:q     r2.7<0;1,0>:q     r1.1<0;1,0>:q   
        mov (1|M0)               r4.0<1>:f     r8.0<0;1,0>:f                    {Compacted}
        add (1|M0)               r44.0<1>:q    r1.2<0;1,0>:q     r42.0<0;1,0>:q   {Compacted,I@3}
        shl (1|M0)               r2.2<1>:q     r3.0<0;1,0>:q     2:w               {Compacted}
        add3 (1|M0)              r4.1<1>:d     r11.0<0;0>:d      r9.0<0;0>:d       r10.0<0>:d       {I@4}
        add (1|M0)               r45.0<1>:q    r1.1<0;1,0>:q     r42.0<0;1,0>:q   {Compacted,I@4}
        add (1|M0)               r43.0<1>:q    r2.4<0;1,0>:q     r4.0<0;1,0>:q    {Compacted,A@1}
        add (1|M0)               r4.0<1>:q     r44.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted}
        add (1|M0)               r5.0<1>:q     r45.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,I@3}
        send.ugm (1|M0)          r48      r44  null:0  0x0            0x0210D580           {$2} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        send.ugm (1|M0)          r50      r45  null:0  0x0            0x0210D580           {$3} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        send.ugm (1|M0)          r47      r4  null:0  0x0            0x0210D580           {I@2,$4} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        send.ugm (1|M0)          r49      r5  null:0  0x0            0x0210D580           {I@1,$5} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        shl (1|M0)               r46.0<1>:d    r3.3<0;1,0>:d     6:w               {Compacted}
        send.ugm (1|M0)          r63      r43  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r59      r43  null:0  0x100000            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        shl (1|M0)               r42.1<1>:q    r42.1<0;1,0>:q    4:w              
        add (1|M0)               r42.4<1>:d    r46.0<0;1,0>:d    512:w               {Compacted,I@2}
        send.slm (1|M0)          null     r46  r48:1  0x0            0x0200C704           {$2} // wr:1+1, rd:0; store.slm.d64x8t.a32
        send.slm (1|M0)          null     r46  r50:1  0x200000            0x0200C704           {$3} // wr:1+1, rd:0; store.slm.d64x8t.a32.flat[A+0x200]
        send.slm (1|M0)          null     r46  r47:1  0x400000            0x0200C704           {$4} // wr:1+1, rd:0; store.slm.d64x8t.a32.flat[A+0x400]
        send.slm (1|M0)          null     r46  r49:1  0x600000            0x0200C704           {$5} // wr:1+1, rd:0; store.slm.d64x8t.a32.flat[A+0x600]
(W)     send.slm (1|M0)          r6       r41  null:0  0x0            0x0210001F           {$8} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r7.2<1>:f     0.0:f                               {Compacted}
(W)     mov (2|M0)               r7.10<1>:ub   r41.11<0;1,0>:ub                 {F@1}
(W)     mov (8|M0)               null<1>:ud    r6.0<1;1,0>:ud                   {Compacted,$8.dst}
(W)     send.gtwy (1|M0)         null     r7  null:0  0x0            0x02000004           {I@2,$9} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (1|M0)    (eq)f1.1   null<1>:d     r3.2<0;1,0>:d     0:w              
(W&f1.1) jmpi                                L3616                                
L1136:
        cmp (1|M0)    (eq)f3.1   null<1>:d     r3.2<0;1,0>:d     1:w              
        mov (1|M0)               r42.3<1>:q    r3.2<0;1,0>:ud                  
(W&f3.1) jmpi                                L1472                                
L1184:
        mul (1|M0)               acc0.0<1>:ud  r3.0<0;1,0>:ud    0x3:uw             
        mach (1|M0)              r7.0<1>:ud    r3.0<0;1,0>:ud    0x3:ud              {$9.src}
        shl (1|M0)               r1.1<1>:q     r3.0<0;1,0>:q     1:w               {Compacted}
        mul (1|M0)               r2.3<1>:d     r3.1<0;1,0>:d     3:w              
        mov (1|M0)               r6.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@3}
        add (1|M0)               r2.5<1>:d     r2.3<0;1,0>:d     r7.0<0;1,0>:d    {I@3}
        mov (1|M0)               r2.4<1>:d     r6.0<0;1,0>:d                    {Compacted,I@3}
        add (1|M0)               r4.0<1>:q     r44.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@3}
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@2}
        sync.nop                             null                             {Compacted,$2.src}
        send.ugm (1|M0)          r48      r4  null:0  0x0            0x0210D580           {I@2,$10} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        add (1|M0)               r5.0<1>:q     r45.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        add (1|M0)               r8.0<1>:q     r44.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,I@2}
        add (1|M0)               r4.0<1>:q     r45.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,$10.src}
        send.ugm (1|M0)          r55      r43  null:0  0x200000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r51      r43  null:0  0x300000            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        sync.nop                             null                             {$3.src}
        send.ugm (1|M0)          r50      r5  null:0  0x0            0x0210D580           {I@3,$13} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        sync.nop                             null                             {Compacted,$4.src}
        send.ugm (1|M0)          r47      r8  null:0  0x0            0x0210D580           {I@2,$14} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        sync.nop                             null                             {Compacted,$5.src}
        send.ugm (1|M0)          r49      r4  null:0  0x0            0x0210D580           {I@1,$15} // wr:1+0, rd:1; load.ugm.d32x16t.a64
L1472:
        mov (1|M0)               r4.0<1>:d     0:w                               {Compacted,$15.src}
        mov (1|M0)               r13.0<1>:d    512:w                               {Compacted}
        sync.allrd                           ($9,$13,$14)                
        send.slm (1|M0)          r5       r4  null:0  0x0            0x0280F700           {I@2,$0} // wr:1+0, rd:8; load.slm.d64x64t.a32
        send.slm (1|M0)          r14      r13  null:0  0x0            0x0280F700           {I@1,$1} // wr:1+0, rd:8; load.slm.d64x64t.a32
        mov (1|M0)               r22.0<1>:d    1024:w                               {Compacted}
        mov (1|M0)               r31.0<1>:d    1536:w                               {Compacted}
        send.slm (1|M0)          r23      r22  null:0  0x0            0x0280F700           {I@2,$8} // wr:1+0, rd:8; load.slm.d64x64t.a32
        send.slm (1|M0)          r33      r31  null:0  0x0            0x0280F700           {I@1,$2} // wr:1+0, rd:8; load.slm.d64x64t.a32
        sync.allwr                           ($0,$1)                
        dpas.8x8 (16|M0)         r82:d         null:d            r63:s4            r5.0:b           {Atomic,$6.dst}
        dpas.8x8 (16|M0)         r68:d         null:d            r63:s4            r9.0:b           {Atomic}
        dpas.8x8 (16|M0)         r114:d        null:d            r63:s4            r14.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r98:d         null:d            r63:s4            r18.0:ub         {$0}
        sync.allwr                           ($0,$2,$8)                
        dpas.8x8 (16|M0)         r82:d         r82:d             r59:s4            r23.0:b          {Atomic,$7.dst}
        dpas.8x8 (16|M0)         r68:d         r68:d             r59:s4            r27.0:b          {Atomic}
        dpas.8x8 (16|M0)         r114:d        r114:d            r59:s4            r33.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r59:s4            r37.0:ub         {$8}
(W&f3.1) jmpi                                L1872                                
L1760:
        sync.nop                             null                             {Compacted,$8.src}
        mov (32|M0)              r59.0<1>:f    r51.0<1;1,0>:f                   {Compacted,$12.dst}
        mov (32|M0)              r61.0<1>:f    r53.0<1;1,0>:f                   {Compacted}
        mov (32|M0)              r63.0<1>:f    r55.0<1;1,0>:f                   {Compacted,$11.dst}
        mov (32|M0)              r65.0<1>:d    r57.0<1;1,0>:d                  
        send.slm (1|M0)          null     r46  r48:1  0x800000            0x0200C704           {$10} // wr:1+1, rd:0; store.slm.d64x8t.a32.flat[A+0x800]
        send.slm (1|M0)          null     r46  r50:1  0xA00000            0x0200C704           {$13} // wr:1+1, rd:0; store.slm.d64x8t.a32.flat[A+0xA00]
        send.slm (1|M0)          null     r46  r47:1  0xC00000            0x0200C704           {$14} // wr:1+1, rd:0; store.slm.d64x8t.a32.flat[A+0xC00]
        send.slm (1|M0)          null     r46  r49:1  0xE00000            0x0200C704           {$15} // wr:1+1, rd:0; store.slm.d64x8t.a32.flat[A+0xE00]
L1872:
(W)     send.slm (1|M0)          r4       r41  null:0  0x0            0x0210001F           {$1} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r5.2<1>:f     0.0:f                               {Compacted}
(W)     mov (2|M0)               r5.10<1>:ub   r41.11<0;1,0>:ub                 {F@1}
(W)     mov (8|M0)               null<1>:ud    r4.0<1;1,0>:ud                   {Compacted,$1.dst}
(W)     send.gtwy (1|M0)         null     r5  null:0  0x0            0x02000004           {I@2,$0} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
(W&f3.1) jmpi                                L3744                                
L1968:
        mov (2|M0)               r42.8<1>:d    0x100:v                              
        mov (1|M0)               r42.5<1>:q    1:w                              
        mul (2|M0)               r42.8<1>:d    r42.8<1;1,0>:d    767:w               {I@2}
        add (2|M0)               r42.8<1>:d    r42.8<1;1,0>:d    -512:w               {I@1}
L2032:
        add (1|M0)               r42.7<1>:q    r42.5<0;1,0>:q    1:w              
(W)     mov (1|M0)               r1.3<1>:hf    0x1:hf                             
        cmp (1|M0)    (eq)f2.0   null<1>:d     r42.15<0;1,0>:d   r42.7<0;1,0>:d   {I@1}
        cmp (1|M0)    (lt)f2.1   null<1>:ud    r42.14<0;1,0>:ud  r42.6<0;1,0>:ud 
        cmp (1|M0)    (lt)f3.0   null<1>:ud    r42.15<0;1,0>:ud  r42.7<0;1,0>:ud 
        shl (1|M0)               r42.6<1>:q    r42.5<0;1,0>:q    9:w              
(f2.0)  sel (1|M0)               r1.4<1>:uw    r1.3<0;1,0>:uw    0x0:uw              {F@1}
(f2.1)  sel (1|M0)               r1.5<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
(f3.0)  sel (1|M0)               r2.7<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        and (1|M0)    (ne)f1.0   null<1>:uw    r1.4<0;1,0>:uw    r1.5<0;1,0>:uw   {I@2}
        add (1|M0)               r42.6<1>:q    r42.6<0;1,0>:q    512:w              
        and (2|M0)               r42.12<1>:d   r42.12<1;1,0>:d   r42.8<1;1,0>:d   {I@1}
(f1.0)  sel (1|M0)               r2.6<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        or (1|M0)     (ne)f0.1   null<1>:uw    r2.6<0;1,0>:uw    r2.7<0;1,0>:uw   {I@1}
(W&~f0.1) jmpi                               L2848                                
L2272:
        mov (2|M0)               r1.16<1>:w    0x86868686:uv                             
        shl (1|M0)               r1.1<1>:q     r42.7<0;1,0>:q    1:w              
        add (2|M0)               r2.3<1>:d     r1.16<1;1,0>:w    -8:w               {I@2}
        mov (2|M0)               r10.0<1>:w    0x1010101:v                              
        and (2|M0)               r1.2<1>:d     r1.2<1;1,0>:d     r2.3<1;1,0>:d    {I@2}
        add (1|M0)               r4.0<1>:uq    r43.0<0;1,0>:uq   r42.6<0;1,0>:uq 
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r3.2<0;1,0>:uw   {I@2}
        macl (1|M0)              r6.0<1>:d     r1.2<0;1,0>:d     r3.1<0;1,0>:d    {Compacted,$5.src}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r3.0<0;1,0>:uw  
        sync.nop                             null                             {Compacted,$11.src}
        macl (1|M0)              r5.0<1>:d     r1.3<0;1,0>:d     r3.0<0;1,0>:d    {$0.src}
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r3.0<0;1,0>:uw  
        mach (1|M0)              r9.0<1>:ud    r1.2<0;1,0>:ud    r3.0<0;1,0>:ud   {Compacted}
        or (2|M0)                r1.2<1>:ud    r1.2<1;1,0>:ud    r10.0<1;1,0>:w  
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r3.2<0;1,0>:uw   {I@2}
        macl (1|M0)              r12.0<1>:d    r1.2<0;1,0>:d     r3.1<0;1,0>:d    {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r3.0<0;1,0>:uw  
        add3 (1|M0)              r1.5<1>:d     r5.0<0;0>:d       r9.0<0;0>:d       r6.0<0>:d       
        macl (1|M0)              r5.0<1>:d     r1.3<0;1,0>:d     r3.0<0;1,0>:d    {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r3.0<0;1,0>:uw  
        mach (1|M0)              r9.0<1>:ud    r1.2<0;1,0>:ud    r3.0<0;1,0>:ud   {Compacted}
        mov (1|M0)               r1.4<1>:d     r8.0<0;1,0>:d                    {Compacted,I@7}
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
        add3 (1|M0)              r2.5<1>:d     r5.0<0;0>:d       r9.0<0;0>:d       r12.0<0>:d       {I@3}
        shl (1|M0)               r1.2<1>:q     r1.2<0;1,0>:q     2:w               {I@3}
        mov (1|M0)               r2.4<1>:d     r8.0<0;1,0>:d                    {Compacted,I@3}
        sync.nop                             null                             {Compacted,$11.dst}
        send.ugm (1|M0)          r55      r4  null:0  0x0            0x0240F580           {$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {Compacted,$12.dst}
        send.ugm (1|M0)          r51      r4  null:0  0x100000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@1}
        add (1|M0)               r4.0<1>:q     r45.0<0;1,0>:q    r1.2<0;1,0>:q    {Compacted,$6.src}
        add (1|M0)               r7.0<1>:q     r44.0<0;1,0>:q    r1.2<0;1,0>:q    {Compacted,$4.src}
        sync.nop                             null                             {Compacted,$13.dst}
        sync.nop                             null                             {Compacted,$3.src}
        send.ugm (1|M0)          r50      r4  null:0  0x0            0x0210D580           {I@2,$7} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        add (1|M0)               r6.0<1>:q     r45.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted}
        add (1|M0)               r4.0<1>:q     r44.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,$7.src}
        sync.nop                             null                             {Compacted,$10.dst}
        sync.nop                             null                             {Compacted,$2.src}
        send.ugm (1|M0)          r48      r7  null:0  0x0            0x0210D580           {I@3,$3} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        sync.nop                             null                             {Compacted,$15.dst}
        sync.nop                             null                             {Compacted,$5.src}
        send.ugm (1|M0)          r49      r6  null:0  0x0            0x0210D580           {I@2,$4} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        sync.nop                             null                             {Compacted,$14.dst}
        sync.nop                             null                             {Compacted,$4.src}
        send.ugm (1|M0)          r47      r4  null:0  0x0            0x0210D580           {I@1,$5} // wr:1+0, rd:1; load.ugm.d32x16t.a64
L2848:
        shl (1|M0)               r1.2<1>:d     r42.10<0;1,0>:d   11:w              
        and (1|M0)               r67.0<1>:d    r1.2<0;1,0>:d     2048:w               {I@1}
        or (1|M0)                r4.0<1>:ud    r67.0<0;1,0>:ud   0x200:uw              {Compacted,@1,$5.src}
        sync.allrd                           ($0,$3,$4,$11)                
        send.slm (1|M0)          r5       r67  null:0  0x0            0x0280F700           {$12} // wr:1+0, rd:8; load.slm.d64x64t.a32
        send.slm (1|M0)          r13      r4  null:0  0x0            0x0280F700           {I@1,$2} // wr:1+0, rd:8; load.slm.d64x64t.a32
        or (1|M0)                r21.0<1>:ud   r67.0<0;1,0>:ud   0x400:uw              {Compacted}
        or (1|M0)                r22.0<1>:ud   r67.0<0;1,0>:ud   0x600:uw              {Compacted}
        sync.nop                             null                             {Compacted,$9.src}
        send.slm (1|M0)          r23      r21  null:0  0x0            0x0280F700           {I@2,$8} // wr:1+0, rd:8; load.slm.d64x64t.a32
        send.slm (1|M0)          r31      r22  null:0  0x0            0x0280F700           {I@1,$10} // wr:1+0, rd:8; load.slm.d64x64t.a32
        sync.allwr                           ($2,$9,$12)                
        dpas.8x8 (16|M0)         r82:d         r82:d             r63:s4            r5.0:b           {Atomic,$8.dst}
        dpas.8x8 (16|M0)         r68:d         r68:d             r63:s4            r9.0:b           {Atomic}
        dpas.8x8 (16|M0)         r114:d        r114:d            r63:s4            r13.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r63:s4            r17.0:ub         {$9}
        sync.allwr                           ($9,$10)                
        dpas.8x8 (16|M0)         r82:d         r82:d             r59:s4            r23.0:b          {Atomic,$8.dst}
        dpas.8x8 (16|M0)         r68:d         r68:d             r59:s4            r27.0:b          {Atomic}
        dpas.8x8 (16|M0)         r114:d        r114:d            r59:s4            r31.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r59:s4            r35.0:ub         {$9}
(W&~f0.1) jmpi                               L3392                                
L3168:
        xor (1|M0)               r1.2<1>:ud    r67.0<0;1,0>:ud   0x800:uw              {Compacted}
        xor (1|M0)               r67.0<1>:ud   r67.0<0;1,0>:ud   0xC00:uw              {Compacted}
        sync.nop                             null                             {Compacted,$6.dst}
        sync.nop                             null                             {Compacted,$9.src}
        mov (32|M0)              r59.0<1>:f    r51.0<1;1,0>:f                   {Compacted,$12.dst}
        mov (32|M0)              r61.0<1>:f    r53.0<1;1,0>:f                   {Compacted}
        sync.nop                             null                             {Compacted,$1.dst}
        mov (32|M0)              r63.0<1>:f    r55.0<1;1,0>:f                   {Compacted,$11.dst}
        mov (32|M0)              r65.0<1>:f    r57.0<1;1,0>:f                   {Compacted}
        mad (1|M0)               r4.0<1>:d     r1.2<0;0>:d       r1.0<0;0>:uw      64:w               {I@2}
        add (1|M0)               r5.0<1>:d     r1.2<0;1,0>:d     r42.4<0;1,0>:d   {Compacted}
        mad (1|M0)               r6.0<1>:d     r67.0<0;0>:d      r1.0<0;0>:uw      64:w               {@3,$5.src}
        add (1|M0)               r7.0<1>:d     r67.0<0;1,0>:d    r42.4<0;1,0>:d   {Compacted,$4.src}
        sync.nop                             null                             {Compacted,$10.dst}
        send.slm (1|M0)          null     r4  r48:1  0x0            0x0200C704           {I@4,$3} // wr:1+1, rd:0; store.slm.d64x8t.a32
        sync.nop                             null                             {$13.dst}
        send.slm (1|M0)          null     r5  r50:1  0x0            0x0200C704           {I@3,$7} // wr:1+1, rd:0; store.slm.d64x8t.a32
        sync.nop                             null                             {Compacted,$14.dst}
        send.slm (1|M0)          null     r6  r47:1  0x0            0x0200C704           {I@2,$5} // wr:1+1, rd:0; store.slm.d64x8t.a32
        sync.nop                             null                             {Compacted,$15.dst}
        send.slm (1|M0)          null     r7  r49:1  0x0            0x0200C704           {I@1,$4} // wr:1+1, rd:0; store.slm.d64x8t.a32
L3392:
        sync.nop                             null                             {Compacted,$3.src}
(W)     send.slm (1|M0)          r4       r41  null:0  0x0            0x0210001F           {$13} // wr:1+0, rd:1; fence.slm.none.group
(W)     mov (1|M0)               r5.2<1>:f     0.0:f                               {Compacted,$7.src}
(W)     mov (2|M0)               r5.10<1>:ub   r41.11<0;1,0>:ub                 {F@1}
(W)     mov (8|M0)               null<1>:ud    r4.0<1;1,0>:ud                   {$13.dst}
(W)     send.gtwy (1|M0)         null     r5  null:0  0x0            0x02000004           {I@2,$11} // wr:1+0, rd:0; signal barrier
(W)     sync.bar                             0x0                                
        cmp (1|M0)    (eq)f1.1   null<1>:d     r42.14<0;1,0>:d   r42.6<0;1,0>:d  
(W)     mov (1|M0)               r1.3<1>:hf    0x1:hf                             
(f2.0)  sel (1|M0)               r2.6<1>:uw    r1.3<0;1,0>:uw    0x0:uw              {F@1}
(f1.1)  sel (1|M0)               r1.4<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        and (1|M0)    (ne)f0.1   null<1>:uw    r1.4<0;1,0>:uw    r2.6<0;1,0>:uw   {I@1}
(W&f0.1) jmpi                                L3744                                
L3584:
        mov (1|M0)               r42.5<1>:q    r42.7<0;1,0>:q                  
(W)     jmpi                                 L2032                                
L3616:
        mov (32|M0)              r68.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r70.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r72.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r74.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r82.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r84.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r86.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r88.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r98.0<1>:d    0:w                               {Compacted}
        mov (32|M0)              r100.0<1>:d   0:w                               {Compacted}
        mov (32|M0)              r102.0<1>:d   0:w                               {Compacted}
        mov (32|M0)              r104.0<1>:d   0:w                               {Compacted}
        mov (32|M0)              r114.0<1>:d   0:w                               {Compacted}
        mov (32|M0)              r116.0<1>:d   0:w                               {Compacted}
        mov (32|M0)              r118.0<1>:d   0:w                               {Compacted}
        mov (32|M0)              r120.0<1>:d   0:w                               {Compacted}
L3744:
        sync.nop                             null                             {$12.src}
        shl (1|M0)               r43.4<1>:q    r43.4<0;1,0>:q    4:w               {$7.src}
        shl (1|M0)               r43.1<1>:q    r42.1<0;1,0>:q    2:w              
        shl (1|M0)               r43.4<1>:q    r43.4<0;1,0>:q    2:w               {I@2}
        sync.nop                             null                             {Compacted,$11.src}
        add (1|M0)               r5.0<1>:q     r3.3<0;1,0>:q     r43.1<0;1,0>:q   {Compacted,@2,$0.src}
        add (1|M0)               r4.0<1>:q     r3.2<0;1,0>:q     r43.4<0;1,0>:q   {I@2}
        send.ugm (1|M0)          r76      r5  null:0  0x0            0x0210D580           {I@2,$0} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        send.ugm (1|M0)          r77      r4  null:0  0x0            0x0210D580           {I@1,$14} // wr:1+0, rd:1; load.ugm.d32x16t.a64
        cmp (1|M0)    (eq)f3.0   null<1>:d     r3.9<0;1,0>:d     0:w              
(f3.0)  cmp (1|M0)    (eq)f3.0   null<1>:d     r3.8<0;1,0>:d     0:w              
(W&f3.0) jmpi                                L3960                                
L3920:
        add (1|M0)               r4.0<1>:q     r3.4<0;1,0>:q     r43.1<0;1,0>:q   {Compacted,$14.src}
        send.ugm (1|M0)          r78      r4  null:0  0x0            0x0210D580           {I@1,$15} // wr:1+0, rd:1; load.ugm.d32x16t.a64
(W)     jmpi                                 L3968                                
L3960:
        mov (16|M0)              r78.0<1>:f    0.0:f                               {Compacted}
L3968:
        cmp (1|M0)    (eq)f2.1   null<1>:d     r3.11<0;1,0>:d    0:w              
(f2.1)  cmp (1|M0)    (eq)f2.1   null<1>:d     r3.10<0;1,0>:d    0:w              
(W&f2.1) jmpi                                L4064                                
L4016:
        sync.nop                             null                             {Compacted,$15.src}
        add (1|M0)               r4.0<1>:q     r3.5<0;1,0>:q     r43.4<0;1,0>:q   {Compacted,$14.src}
        send.ugm (1|M0)          r79      r4  null:0  0x0            0x0210D580           {I@1,$1} // wr:1+0, rd:1; load.ugm.d32x16t.a64
(W)     jmpi                                 L4072                                
L4064:
        mov (16|M0)              r79.0<1>:f    0.0:f                               {Compacted}
L4072:
        sync.nop                             null                             {Compacted,$9.dst}
        sync.nop                             null                             {$0.src}
        mov (16|M0)              r5.0<1>:f     r82.0<1;1,0>:d                   {$8.dst}
        mov (1|M0)               r2.3<1>:f     256.0:f                              
        sync.allrd                           ($1,$15)                
        mov (16|M0)              r4.0<1>:f     r114.0<1;1,0>:d                  {$14.src}
        mad (16|M0)              acc0.0<1>:f   r4.0<1;0>:f       r5.0<1;0>:f       r2.3<0>:f        {Compacted,F@1}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.0<0;1,0>:f   {Compacted,$15.dst}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted,$14.dst}
        sync.nop                             null                             {Compacted,$1.dst}
        sync.nop                             null                             {Compacted,$5.src}
        mad (16|M0)              r6.0<1>:f     r79.0<1;0>:f      acc0.0<1;0>:f     r76.0<0>:f       {Compacted,$0.dst}
        mul (1|M0)               acc0.0<1>:ud  r42.2<0;1,0>:ud   r3.28<0;1,0>:uw  {F@1}
        mach (1|M0)              r9.0<1>:ud    r42.2<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        mov (16|M0)              r11.0<1>:f    r83.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r115.0<1;1,0>:d                 
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r42.2<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r10.0<1>:d    r42.2<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r42.3<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r5.0<1>:w     0x1010101:v                              
        macl (1|M0)              r7.0<1>:d     r42.3<0;1,0>:d    r3.14<0;1,0>:d   {Compacted,$4.src}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        mov (1|M0)               r1.2<1>:d     r8.0<0;1,0>:d                    {Compacted}
        or (2|M0)                r2.4<1>:d     r42.2<1;1,0>:d    r5.0<1;1,0>:w   
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r9.0<0;0>:d       r10.0<0>:d      
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.1<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        add (1|M0)               r43.4<1>:q    r3.6<0;1,0>:q     r43.4<0;1,0>:q  
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mad (16|M0)              r13.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.1<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {F@1}
        mach (1|M0)              r9.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        add (1|M0)               r4.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {I@3}
        mov (16|M0)              r11.0<1>:f    r84.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r116.0<1;1,0>:d                 
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        send.ugm (1|M0)          null     r4  r6:1  0x0            0x0200D584           {I@3,$6} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        macl (1|M0)              r4.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d   {$6.src}
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        mov (2|M0)               r7.0<1>:w     0x2020202:v                              
        macl (1|M0)              r5.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        mov (1|M0)               r1.2<1>:d     r8.0<0;1,0>:d                    {Compacted}
        or (2|M0)                r10.0<1>:d    r42.2<1;1,0>:d    r7.0<1;1,0>:w   
        add3 (1|M0)              r1.3<1>:d     r5.0<0;0>:d       r9.0<0;0>:d       r4.0<0>:d       
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.2<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@1}
        mad (16|M0)              r14.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.2<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r10.0<0;1,0>:ud   r3.28<0;1,0>:uw  {F@1}
        mach (1|M0)              r5.0<1>:ud    r10.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        add (1|M0)               r6.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@3}
        mov (16|M0)              r11.0<1>:f    r85.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r117.0<1;1,0>:d                 
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r10.0<0;1,0>:d    r3.30<0;1,0>:uw 
        send.ugm (1|M0)          null     r6  r13:1  0x0            0x0200D584           {I@3,$7} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        macl (1|M0)              r6.0<1>:d     r10.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted,$7.src}
(W)     mul (1|M0)               acc0.0<1>:d   r10.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0x3030303:v                              
        macl (1|M0)              r7.0<1>:d     r10.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r42.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.3<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r10.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.3<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r13.0<1>:f    r86.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r118.0<1;1,0>:d                 
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0x4040404:v                              
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r11.0<1>:d    r42.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.4<0;1,0>:f   {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$8} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.4<0>:f       {Compacted,$8.src}
        mul (1|M0)               acc0.0<1>:ud  r11.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r11.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r10:1  0x0            0x0200D584           {I@2,$9} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r13.0<1>:f    r87.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r10.0<1>:f    r119.0<1;1,0>:d                  {$9.src}
(W)     mul (1|M0)               acc0.0<1>:d   r11.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r11.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r11.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0x5050505:v                              
        macl (1|M0)              r7.0<1>:d     r11.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r10.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r42.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.5<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r11.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.5<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r12.0<1>:f    r120.0<1;1,0>:d                 
        mov (16|M0)              r13.0<1>:f    r88.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0x6060606:v                              
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r10.0<1>:d    r42.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.6<0;1,0>:f   {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$10} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.6<0>:f       {Compacted,$10.src}
        mul (1|M0)               acc0.0<1>:ud  r10.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r10.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r11:1  0x0            0x0200D584           {I@2,$11} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r12.0<1>:f    r121.0<1;1,0>:d                 
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r11.0<1>:f    r89.0<1;1,0>:d                   {$11.src}
(W)     mul (1|M0)               acc0.0<1>:d   r10.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r10.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r10.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0x7070707:v                              
        macl (1|M0)              r7.0<1>:d     r10.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r42.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.7<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r10.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.7<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r13.0<1>:f    r68.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r98.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0x8080808:uv                             
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r11.0<1>:d    r42.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.8<0;1,0>:f   {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$12} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.8<0>:f       {Compacted,$12.src}
        mul (1|M0)               acc0.0<1>:ud  r11.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r11.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r10:1  0x0            0x0200D584           {I@2,$13} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r13.0<1>:f    r69.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r10.0<1>:f    r99.0<1;1,0>:d                   {$13.src}
(W)     mul (1|M0)               acc0.0<1>:d   r11.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r11.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r11.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0x9090909:uv                             
        macl (1|M0)              r7.0<1>:d     r11.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r10.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r42.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.9<0;1,0>:f   {Compacted}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r11.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.9<0>:f       {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r12.0<1>:f    r100.0<1;1,0>:d                 
        mov (16|M0)              r13.0<1>:f    r70.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0xA0A0A0A:uv                             
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r10.0<1>:d    r42.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.10<0;1,0>:f  {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$14} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.10<0>:f      {Compacted,$14.src}
        mul (1|M0)               acc0.0<1>:ud  r10.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r10.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r11:1  0x0            0x0200D584           {I@2,$15} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r12.0<1>:f    r101.0<1;1,0>:d                 
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r11.0<1>:f    r71.0<1;1,0>:d                   {$15.src}
(W)     mul (1|M0)               acc0.0<1>:d   r10.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r10.0<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r10.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0xB0B0B0B:uv                             
        macl (1|M0)              r7.0<1>:d     r10.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r42.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.11<0;1,0>:f  {Compacted}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r10.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.11<0>:f      {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r13.0<1>:f    r72.0<1;1,0>:d                  
        mov (16|M0)              r12.0<1>:f    r102.0<1;1,0>:d                 
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0xC0C0C0C:uv                             
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                   
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r11.0<1>:d    r42.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.12<0;1,0>:f 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$0} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.12<0>:f      {Compacted,$0.src}
        mul (1|M0)               acc0.0<1>:ud  r11.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r11.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r10:1  0x0            0x0200D584           {I@2,$1} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r13.0<1>:f    r73.0<1;1,0>:d                  
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r10.0<1>:f    r103.0<1;1,0>:d                  {$1.src}
(W)     mul (1|M0)               acc0.0<1>:d   r11.0<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r11.0<0;1,0>:d    r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r11.1<0;1,0>:d    r3.28<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0xD0D0D0D:uv                             
        macl (1|M0)              r7.0<1>:d     r11.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r10.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r2.4<1>:d     r42.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.13<0;1,0>:f 
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mad (16|M0)              r11.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.13<0>:f      {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r2.4<0;1,0>:ud    r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r2.4<0;1,0>:ud    r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r2.4<0;1,0>:d     r3.30<0;1,0>:uw 
        mov (16|M0)              r12.0<1>:f    r104.0<1;1,0>:d                 
        mov (16|M0)              r13.0<1>:f    r74.0<1;1,0>:d                  
        macl (1|M0)              r6.0<1>:d     r2.4<0;1,0>:d     r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r2.5<0;1,0>:d     r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r2.5<0;1,0>:d     r3.14<0;1,0>:d  
        mov (2|M0)               r9.0<1>:w     0xE0E0E0E:uv                             
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r13.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        or (2|M0)                r10.0<1>:d    r42.2<1;1,0>:d    r9.0<1;1,0>:w    {I@4}
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.14<0;1,0>:f  {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        mul (16|M0)              acc0.0<1>:f   r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {$2} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mad (16|M0)              r14.0<1>:f    r79.0<1;0>:f      acc0.0<1;0>:f     r76.14<0>:f      {Compacted,$2.src}
        mul (1|M0)               acc0.0<1>:ud  r10.0<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mach (1|M0)              r5.0<1>:ud    r10.0<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          null     r8  r11:1  0x0            0x0200D584           {I@2,$3} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        mov (16|M0)              r12.0<1>:f    r105.0<1;1,0>:d                 
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
        mov (16|M0)              r11.0<1>:f    r75.0<1;1,0>:d                   {$3.src}
(W)     mul (1|M0)               acc0.0<1>:d   r10.0<0;1,0>:d    r3.30<0;1,0>:uw 
        mov (2|M0)               r9.0<1>:w     0xF0F0F0F:uv                             
        macl (1|M0)              r6.0<1>:d     r10.0<0;1,0>:d    r3.15<0;1,0>:d  
(W)     mul (1|M0)               acc0.0<1>:d   r10.1<0;1,0>:d    r3.28<0;1,0>:uw 
        macl (1|M0)              r7.0<1>:d     r10.1<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        mad (16|M0)              acc0.0<1>:f   r12.0<1;0>:f      r11.0<1;0>:f      r2.3<0>:f        {Compacted,A@1}
        or (2|M0)                r42.2<1>:d    r42.2<1;1,0>:d    r9.0<1;1,0>:w   
        add (16|M0)              acc0.0<1>:f   acc0.0<1;1,0>:f   r78.15<0;1,0>:f  {Compacted}
        mul (16|M0)              r77.0<1>:f    r77.0<1;1,0>:f    acc0.0<1;1,0>:f  {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r42.2<0;1,0>:ud   r3.28<0;1,0>:uw  {A@1}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d       
        mach (1|M0)              r5.0<1>:ud    r42.2<0;1,0>:ud   r3.14<0;1,0>:ud  {Compacted}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r4.0<1>:ud    acc0.0<0;1,0>:ud                
(W)     mul (1|M0)               acc0.0<1>:d   r42.2<0;1,0>:d    r3.30<0;1,0>:uw 
        macl (1|M0)              r6.0<1>:d     r42.2<0;1,0>:d    r3.15<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r42.3<0;1,0>:d    r3.28<0;1,0>:uw 
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r42.3<0;1,0>:d    r3.14<0;1,0>:d   {Compacted}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        mov (1|M0)               r1.2<1>:d     r4.0<0;1,0>:d                    {Compacted}
        add3 (1|M0)              r1.3<1>:d     r7.0<0;0>:d       r5.0<0;0>:d       r6.0<0>:d        {I@3}
        send.ugm (1|M0)          null     r8  r14:1  0x0            0x0200D584           {I@3,$4} // wr:1+1, rd:0; store.ugm.d32x16t.a64
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@1}
(W)     mov (16|M0)              r127.0<1>:f   r41.0<1;1,0>:f                   {Compacted}
        mad (16|M0)              r10.0<1>:f    r79.0<1;0>:f      r77.0<1;0>:f      r76.15<0>:f      {Compacted}
        add (1|M0)               r8.0<1>:q     r43.4<0;1,0>:q    r1.1<0;1,0>:q    {@1,$4.src}
        send.ugm (1|M0)          null     r8  r10:1  0x0            0x0200D584           {A@1,$5} // wr:1+1, rd:0; store.ugm.d32x16t.a64
(W)     send.gtwy (1|M0)         null     r127  null:0  0x0            0x02000010           {EOT,$6} // wr:1+0, rd:0; end of thread
L8256:
        mov (2|M0)               r81.0<1>:d    0x1:v                              
        mov (1|M0)               r42.5<1>:d    63:w                              
        mov (1|M0)               r43.6<1>:q    0:w                              
        mov (1|M0)               r43.7<1>:q    0:w                              
L8320:
        mov (1|M0)               r43.4<1>:q    r42.5<0;1,0>:ud                  {I@3}
        shl (1|M0)               r43.6<1>:q    r43.6<0;1,0>:q    1:w               {I@3}
        shr (1|M0)               r4.0<1>:uq    r43.2<0;1,0>:uq   r43.4<0;1,0>:uq  {I@2}
(W)     mov (1|M0)               r1.3<1>:hf    0x1:hf                             
        bfn.0xEA (2|M0)          r4.0<1>:ud    r43.12<1;0>:ud    r4.0<1;0>:ud      r81.0<1>:ud      {I@1} // s0|s1&s2
        shl (1|M0)               r43.4<1>:uq   r1.3<0;1,0>:uw    r43.4<0;1,0>:uq  {F@1}
        cmp (1|M0)    (lt)f0.0   null<1>:ud    r4.0<0;1,0>:ud    r43.6<0;1,0>:ud  {I@2}
        cmp (1|M0)    (lt)f1.0   null<1>:ud    r4.1<0;1,0>:ud    r43.7<0;1,0>:ud 
        add (1|M0)               r43.10<1>:ud  r42.5<0;1,0>:ud   0xFFFFFFFF:ud             
        add (1|M0)               r43.6<1>:q    r4.0<0;1,0>:q     -r43.3<0;1,0>:q 
(f0.0)  cmp (1|M0)    (eq)f0.0   null<1>:d     r4.1<0;1,0>:d     r43.7<0;1,0>:d  
(f1.0)  sel (1|M0)               r1.5<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        or (2|M0)                r43.8<1>:d    r43.8<1;1,0>:d    r43.14<1;1,0>:d  {I@7}
(f0.0)  sel (1|M0)               r1.4<1>:uw    r1.3<0;1,0>:uw    0x0:uw             
        cmp (1|M0)    (eq)f0.0   null<1>:d     r42.5<0;1,0>:d    0:w              
        or (1|M0)     (ne)f2.0   null<1>:uw    r1.4<0;1,0>:uw    r1.5<0;1,0>:uw   {I@2}
(f2.0)  mov (1|M0)               r43.12<1>:ud  r4.0<0;1,0>:d                   
(f2.0)  mov (1|M0)               r43.13<1>:ud  r4.1<0;1,0>:d                   
(f2.0)  mov (1|M0)               r43.8<1>:ud   r43.14<0;1,0>:d                 
(f2.0)  mov (1|M0)               r43.9<1>:ud   r43.15<0;1,0>:d                 
(W&f0.0) jmpi                                L8704                                
L8656:
        mov (1|M0)               r42.5<1>:d    r43.10<0;1,0>:d                 
        mov (1|M0)               r43.7<1>:q    r43.4<0;1,0>:q                   {I@3}
(W)     jmpi                                 L8320                                
L8704:
        sync.allrd                           null                             {A@1}
        sync.allwr                           null                            
        ret (32|M0)                          r44.2                            {A@1}
L8752:
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
        illegal                
