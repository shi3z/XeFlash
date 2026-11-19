        or (2|M0)                r1.2<1>:d     r126.8<1;1,0>:d   r126.4<1;1,0>:d  {I@4}
        shl (1|M0)               r126.3<1>:q   r126.3<0;1,0>:q   2:w
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r27.4<0;1,0>:uw  {I@2}
        shl (1|M0)               r27.3<1>:q    r27.3<0;1,0>:q    2:w
        mach (1|M0)              r15.0<1>:ud   r1.2<0;1,0>:ud    r27.2<0;1,0>:ud  {Compacted}
        add (1|M0)               r6.0<1>:q     r124.0<0;1,0>:q   r126.3<0;1,0>:q  {Compacted,I@4}
        or (2|M0)                r4.6<1>:d     r126.8<1;1,0>:d   r27.8<1;1,0>:d
        add (1|M0)               r8.0<1>:q     r28.0<0;1,0>:q    r27.3<0;1,0>:q   {Compacted,I@4}
        mov (1|M0)               r14.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r27.6<0;1,0>:uw
        send.ugm (1|M0)          r11      r6  null:0  0x0            0x0210C580           {I@5,$8} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        macl (1|M0)              r6.0<1>:d     r1.2<0;1,0>:d     r27.3<0;1,0>:d   {$8.src}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r27.4<0;1,0>:uw
        send.ugm (1|M0)          r9       r8  null:0  0x0            0x0210C580           {I@5,$9} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        macl (1|M0)              r8.0<1>:d     r1.3<0;1,0>:d     r27.2<0;1,0>:d   {Compacted,$9.src}
        mul (1|M0)               acc0.0<1>:ud  r4.6<0;1,0>:ud    r27.4<0;1,0>:uw
        mach (1|M0)              r25.0<1>:ud   r4.6<0;1,0>:ud    r27.2<0;1,0>:ud  {Compacted}
        add3 (1|M0)              r2.5<1>:d     r8.0<0;0>:d       r15.0<0;0>:d      r6.0<0>:d        {I@3}
        mov (1|M0)               r24.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.6<0;1,0>:d     r27.6<0;1,0>:uw
        macl (1|M0)              r6.0<1>:d     r4.6<0;1,0>:d     r27.3<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.7<0;1,0>:d     r27.4<0;1,0>:uw
        send.ugm (1|M0)          r16      r123  null:0  0x100000            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r20      r123  null:0  0x0            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r5.0<1>:q     r28.0<0;1,0>:q    r126.3<0;1,0>:q  {Compacted}
        mov (1|M0)               r2.4<1>:d     r14.0<0;1,0>:d                   {Compacted}
        macl (1|M0)              r8.0<1>:d     r4.7<0;1,0>:d     r27.2<0;1,0>:d
        shl (1|M0)               r123.0<1>:q   r27.5<0;1,0>:q    10:w               {$13.src}
        send.ugm (1|M0)          r7       r5  null:0  0x0            0x0210C580           {I@4,$4} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r10.0<1>:q    r124.0<0;1,0>:q   r27.3<0;1,0>:q   {Compacted}
        mov (1|M0)               r1.2<1>:d     r24.0<0;1,0>:d                   {Compacted}
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@5}
        add3 (1|M0)              r1.3<1>:d     r8.0<0;0>:d       r25.0<0;0>:d      r6.0<0>:d        {I@5}
        add (1|M0)               r5.0<1>:q     r126.1<0;1,0>:q   r123.0<0;1,0>:q  {@5,$4.src}
        send.ugm (1|M0)          r13      r10  null:0  0x0            0x0210C580           {I@5,$3} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.allrd                           ($0,$12)
        send.ugm (1|M0)          r119     r5  null:0  0x0            0x0240F580           {I@1,$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.allrd                           ($2,$14)
        send.ugm (1|M0)          r29      r5  null:0  0x100000            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w
        add (1|M0)               r10.0<1>:q    r124.0<0;1,0>:q   r2.2<0;1,0>:q    {Compacted,$3.src}
        add (1|M0)               r5.0<1>:q     r28.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,$6.src}
        sync.nop                             null                             {Compacted,$15.src}
        send.ugm (1|M0)          r117     r10  null:0  0x0            0x0210C580           {I@2,$5} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r115     r5  null:0  0x0            0x0210C580           {I@1,$12} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r10.0<1>:q    r28.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,$5.src}
        add (1|M0)               r5.0<1>:q     r124.0<0;1,0>:q   r1.1<0;1,0>:q    {$12.src}
        send.ugm (1|M0)          r111     r10  null:0  0x0            0x0210C580           {I@2,$11} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.allrd                           ($1,$11)
        send.ugm (1|M0)          r113     r5  null:0  0x0            0x0210C580           {I@1,$14} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r27.6<1>:q    r126.4<0;1,0>:q   4:w
(W)     mov (1|M0)               r2.6<1>:hf    0x1:hf
        cmp (1|M0)    (lt)f2.1   null<1>:ud    r27.12<0;1,0>:ud  r2.14<0;1,0>:ud  {I@1}
        cmp (1|M0)    (lt)f0.0   null<1>:ud    r27.13<0;1,0>:ud  r2.15<0;1,0>:ud
(f2.1)  cmp (1|M0)    (eq)f2.1   null<1>:d     r27.13<0;1,0>:d   r2.15<0;1,0>:d
(f0.0)  sel (1|M0)               r1.4<1>:uw    r2.6<0;1,0>:uw    0x0:uw              {F@1}
(f2.1)  sel (1|M0)               r1.3<1>:uw    r2.6<0;1,0>:uw    0x0:uw
        or (1|M0)     (ne)f1.0   null<1>:uw    r1.3<0;1,0>:uw    r1.4<0;1,0>:uw   {I@1}
        sync.allwr                           ($5,$8,$13)
        dpas.8x1 (16|M0)         r42:d         r42:d             r20:s4            r11.0:b          {Compacted,$15}
        sync.allwr                           ($4,$12)
        dpas.8x1 (16|M0)         r34:d         r34:d             r20:s4            r7.0:ub          {$0}
        sync.allwr                           ($3,$10,$11)
        dpas.8x1 (16|M0)         r38:d         r38:d             r16:s4            r13.0:b          {Compacted,$1}
        sync.allwr                           ($9,$14)
        dpas.8x1 (16|M0)         r36:d         r36:d             r16:s4            r9.0:ub          {$2}
(W&~f1.0) jmpi                               L3664
        mul (1|M0)               acc0.0<1>:ud  r27.12<0;1,0>:ud  r27.4<0;1,0>:uw
        mach (1|M0)              r7.0<1>:ud    r27.12<0;1,0>:ud  r27.2<0;1,0>:ud  {Compacted,$0.src}
        add (1|M0)               r126.4<1>:q   r126.4<0;1,0>:q   5:w
        mov (1|M0)               r6.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r27.12<0;1,0>:d   r27.6<0;1,0>:uw
        macl (1|M0)              r8.0<1>:d     r27.12<0;1,0>:d   r27.3<0;1,0>:d
(W)     mul (1|M0)               acc0.0<1>:d   r27.13<0;1,0>:d   r27.4<0;1,0>:uw
        macl (1|M0)              r5.0<1>:d     r27.13<0;1,0>:d   r27.2<0;1,0>:d   {Compacted,$14.src}
        mul (1|M0)               acc0.0<1>:ud  r126.8<0;1,0>:ud  r27.4<0;1,0>:uw  {I@6}
        mach (1|M0)              r11.0<1>:ud   r126.8<0;1,0>:ud  r27.2<0;1,0>:ud  {Compacted,$15.src}
        sync.allwr                           ($5,$7)
        dpas.8x1 (16|M0)         r42:d         r42:d             r119:s4           r117.0:b         {Compacted,$15}
        sync.nop                             null                             {Compacted,$12.dst}
        dpas.8x1 (16|M0)         r34:d         r34:d             r119:s4           r115.0:ub        {$0}
        mov (1|M0)               r10.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted,$11.src}
(W)     mul (1|M0)               acc0.0<1>:d   r126.8<0;1,0>:d   r27.6<0;1,0>:uw
        macl (1|M0)              r12.0<1>:d    r126.8<0;1,0>:d   r27.3<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r126.9<0;1,0>:d   r27.4<0;1,0>:uw
        macl (1|M0)              r9.0<1>:d     r126.9<0;1,0>:d   r27.2<0;1,0>:d   {Compacted,$2.src}
        sync.allwr                           ($6,$14)
        dpas.8x1 (16|M0)         r38:d         r38:d             r29:s4            r113.0:b         {Compacted,$1}
        sync.nop                             null                             {$11.dst}
        dpas.8x1 (16|M0)         r36:d         r36:d             r29:s4            r111.0:ub        {$2}
        add (1|M0)               r123.0<1>:q   r27.2<0;1,0>:q    r123.0<0;1,0>:q
        add (1|M0)               r27.5<1>:q    r27.5<0;1,0>:q    1:w
        mov (1|M0)               r126.6<1>:d   r6.0<0;1,0>:d
        add3 (1|M0)              r126.7<1>:d   r5.0<0;0>:d       r7.0<0;0>:d       r8.0<0>:d        {I@7}
        mov (1|M0)               r27.6<1>:d    r10.0<0;1,0>:d                   {I@7}
        mov (1|M0)               r126.4<1>:q   r27.6<0;1,0>:q
        add3 (1|M0)              r27.7<1>:d    r9.0<0;0>:d       r11.0<0;0>:d      r12.0<0>:d       {I@7}
(W)     jmpi                                 L2320
