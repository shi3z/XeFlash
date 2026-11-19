        or (2|M0)                r19.0<1>:d    r4.14<1;1,0>:d    r126.8<1;1,0>:d  {I@3}
        or (2|M0)                r26.0<1>:d    r4.14<1;1,0>:d    r1.8<1;1,0>:d
        mul (1|M0)               acc0.0<1>:ud  r19.0<0;1,0>:ud   r126.4<0;1,0>:uw {I@2}
        mach (1|M0)              r21.0<1>:ud   r19.0<0;1,0>:ud   r126.2<0;1,0>:ud {Compacted}
        shl (1|M0)               r1.5<1>:q     r1.5<0;1,0>:q     2:w
        mov (1|M0)               r20.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r19.0<0;1,0>:d    r126.6<0;1,0>:uw
        macl (1|M0)              r22.0<1>:d    r19.0<0;1,0>:d    r126.3<0;1,0>:d  {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r19.1<0;1,0>:d    r126.4<0;1,0>:uw
        macl (1|M0)              r23.0<1>:d    r19.1<0;1,0>:d    r126.2<0;1,0>:d  {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r26.0<0;1,0>:ud   r126.4<0;1,0>:uw {I@7}
        mach (1|M0)              r29.0<1>:ud   r26.0<0;1,0>:ud   r126.2<0;1,0>:ud {Compacted}
        mov (1|M0)               r24.0<1>:f    r20.0<0;1,0>:f                   {Compacted,I@7}
        mov (1|M0)               r28.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r26.0<0;1,0>:d    r126.6<0;1,0>:uw
        macl (1|M0)              r30.0<1>:d    r26.0<0;1,0>:d    r126.3<0;1,0>:d  {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r26.1<0;1,0>:d    r126.4<0;1,0>:uw
        macl (1|M0)              r31.0<1>:d    r26.1<0;1,0>:d    r126.2<0;1,0>:d  {Compacted}
        add3 (1|M0)              r24.1<1>:d    r23.0<0;0>:d      r21.0<0;0>:d      r22.0<0>:d       {I@7}
        mov (1|M0)               r32.0<1>:f    r28.0<0;1,0>:f                   {Compacted,I@6}
        add3 (1|M0)              r32.1<1>:d    r31.0<0;0>:d      r29.0<0;0>:d      r30.0<0>:d       {I@2}
        send.ugm (1|M0)          r10      r125  null:0  0x100000            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r14      r125  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        shl (1|M0)               r24.0<1>:q    r24.0<0;1,0>:q    2:w               {Compacted,A@2}
        shl (1|M0)               r32.0<1>:q    r32.0<0;1,0>:q    2:w               {Compacted,A@1}
        shl (1|M0)               r125.0<1>:q   r4.6<0;1,0>:q     10:w               {Compacted,$6.src}
        add (1|M0)               r6.0<1>:q     r1.2<0;1,0>:q     r1.5<0;1,0>:q    {Compacted}
        add (1|M0)               r25.0<1>:q    r1.2<0;1,0>:q     r24.0<0;1,0>:q   {Compacted,I@4}
        add (1|M0)               r33.0<1>:q    r1.2<0;1,0>:q     r32.0<0;1,0>:q   {Compacted,I@4}
        add (1|M0)               r18.0<1>:q    r126.2<0;1,0>:q   r125.0<0;1,0>:q  {Compacted,I@4}
        send.ugm (1|M0)          r5       r124  null:0  0x0            0x0210C580           {$7} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r7       r6  null:0  0x0            0x0210C580           {I@4,$8} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.nop                             null                             {Compacted,$3.src}
        send.ugm (1|M0)          r119     r25  null:0  0x0            0x0210C580           {I@3,$9} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.nop                             null                             {$4.src}
        send.ugm (1|M0)          r117     r33  null:0  0x0            0x0210C580           {I@2,$10} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r37      r18  null:0  0x0            0x0240F580           {I@1,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r120     r18  null:0  0x100000            0x0240F580           {$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r1.6<1>:q     r4.7<0;1,0>:q     4:w
(W)     mov (1|M0)               r34.0<1>:hf   0x1:hf
        cmp (1|M0)    (lt)f1.1   null<1>:ud    r1.12<0;1,0>:ud   r2.14<0;1,0>:ud  {I@1}
        cmp (1|M0)    (lt)f3.0   null<1>:ud    r1.13<0;1,0>:ud   r2.15<0;1,0>:ud
(f1.1)  cmp (1|M0)    (eq)f1.1   null<1>:d     r1.13<0;1,0>:d    r2.15<0;1,0>:d
(f3.0)  sel (1|M0)               r36.0<1>:uw   r34.0<0;1,0>:uw   0x0:uw              {F@1}
(f1.1)  sel (1|M0)               r35.0<1>:uw   r34.0<0;1,0>:uw   0x0:uw
        or (1|M0)     (ne)f1.0   null<1>:uw    r35.0<0;1,0>:uw   r36.0<0;1,0>:uw  {I@1}
        sync.allwr                           ($6,$7)
        dpas.8x1 (16|M0)         r42:d         r42:d             r14:s4            r5.0:b           {Compacted,$3}
        sync.allwr                           ($5,$8)
        dpas.8x1 (16|M0)         r44:d         r44:d             r10:s4            r7.0:b           {Compacted,$4}
(W&f1.0) jmpi                                L2112
        sync.allwr                           ($3,$11)
        dpas.8x1 (16|M0)         r42:d         r42:d             r37:s4            r119.0:b         {Compacted,$9}
        sync.allwr                           ($4,$12)
        dpas.8x1 (16|M0)         r44:d         r44:d             r120:s4           r117.0:b         {Compacted,$10}
(W)     jmpi                                 L2496
        mul (1|M0)               acc0.0<1>:ud  r1.12<0;1,0>:ud   r126.4<0;1,0>:uw
        mach (1|M0)              r7.0<1>:ud    r1.12<0;1,0>:ud   r126.2<0;1,0>:ud {Compacted,$4.src}
        add (1|M0)               r4.7<1>:q     r4.7<0;1,0>:q     5:w
        mov (1|M0)               r6.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r1.12<0;1,0>:d    r126.6<0;1,0>:uw
        macl (1|M0)              r8.0<1>:d     r1.12<0;1,0>:d    r126.3<0;1,0>:d  {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r1.13<0;1,0>:d    r126.4<0;1,0>:uw
        macl (1|M0)              r9.0<1>:d     r1.13<0;1,0>:d    r126.2<0;1,0>:d  {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r4.14<0;1,0>:ud   r126.4<0;1,0>:uw {I@6}
        mach (1|M0)              r11.0<1>:ud   r4.14<0;1,0>:ud   r126.2<0;1,0>:ud {Compacted}
        mov (1|M0)               r124.0<1>:f   r6.0<0;1,0>:f                    {Compacted,I@7}
        add3 (1|M0)              r124.1<1>:d   r9.0<0;0>:d       r7.0<0;0>:d       r8.0<0>:d        {I@3}
        mov (1|M0)               r10.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.14<0;1,0>:d    r126.6<0;1,0>:uw
        macl (1|M0)              r12.0<1>:d    r4.14<0;1,0>:d    r126.3<0;1,0>:d  {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.15<0;1,0>:d    r126.4<0;1,0>:uw
        shl (1|M0)               r124.0<1>:q   r124.0<0;1,0>:q   2:w               {Compacted,A@1}
        macl (1|M0)              r13.0<1>:d    r4.15<0;1,0>:d    r126.2<0;1,0>:d
        sync.allwr                           ($9,$11)
        dpas.8x1 (16|M0)         r42:d         r42:d             r37:s4            r119.0:b         {Compacted,$3}
        sync.allwr                           ($10,$12)
        dpas.8x1 (16|M0)         r44:d         r44:d             r120:s4           r117.0:b         {Compacted,$4}
        add (1|M0)               r125.0<1>:q   r1.3<0;1,0>:q     r125.0<0;1,0>:q  {Compacted}
        add (1|M0)               r4.6<1>:q     r4.6<0;1,0>:q     1:w
        mov (1|M0)               r1.10<1>:d    r10.0<0;1,0>:d                   {I@7}
        add (1|M0)               r124.0<1>:q   r1.2<0;1,0>:q     r124.0<0;1,0>:q  {I@5}
        mov (1|M0)               r4.7<1>:q     r1.6<0;1,0>:q
        add3 (1|M0)              r1.11<1>:d    r13.0<0;0>:d      r11.0<0;0>:d      r12.0<0>:d       {I@6}
(W)     jmpi                                 L1392
