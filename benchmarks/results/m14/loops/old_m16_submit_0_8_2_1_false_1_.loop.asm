        mul (1|M0)               acc0.0<1>:ud  r25.6<0;1,0>:ud   r25.8<0;1,0>:uw  {I@1}
        mach (1|M0)              r7.0<1>:ud    r25.6<0;1,0>:ud   r25.4<0;1,0>:ud  {Compacted,$3.src}
        shl (1|M0)               r1.1<1>:q     r25.3<0;1,0>:q    8:w
        mov (1|M0)               r6.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted,$12.src}
(W)     mul (1|M0)               acc0.0<1>:d   r25.6<0;1,0>:d    r25.10<0;1,0>:uw
        add (1|M0)               r5.0<1>:q     r26.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,@3,$10.src}
        macl (1|M0)              r8.0<1>:d     r25.6<0;1,0>:d    r25.5<0;1,0>:d   {Compacted}
        or (2|M0)                r1.2<1>:d     r25.6<1;1,0>:d    r25.8<1;1,0>:d
(W)     mul (1|M0)               acc0.0<1>:d   r25.7<0;1,0>:d    r25.8<0;1,0>:uw
        macl (1|M0)              r9.0<1>:d     r25.7<0;1,0>:d    r25.4<0;1,0>:d
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r25.8<0;1,0>:uw  {I@3}
        add3 (1|M0)              r2.5<1>:d     r9.0<0;0>:d       r7.0<0;0>:d       r8.0<0>:d        {I@2}
        mach (1|M0)              r9.0<1>:ud    r1.2<0;1,0>:ud    r25.4<0;1,0>:ud  {Compacted}
        mov (1|M0)               r2.4<1>:d     r6.0<0;1,0>:d                    {Compacted}
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r25.10<0;1,0>:uw
        macl (1|M0)              r24.0<1>:d    r1.2<0;1,0>:d     r25.5<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r25.8<0;1,0>:uw
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@5}
        macl (1|M0)              r7.0<1>:d     r1.3<0;1,0>:d     r25.4<0;1,0>:d   {Compacted}
        add (1|M0)               r10.0<1>:q    r27.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,I@2}
        mov (1|M0)               r2.4<1>:d     r8.0<0;1,0>:d
        add3 (1|M0)              r2.5<1>:d     r7.0<0;0>:d       r9.0<0;0>:d       r24.0<0>:d       {I@3}
        shl (1|M0)               r1.2<1>:q     r1.1<0;1,0>:q     8:w
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@2}
        sync.nop                             null                             {$11.src}
        send.ugm (1|M0)          r19      r5  null:0  0x0            0x0240F580           {$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r6.0<1>:q     r26.0<0;1,0>:q    r1.2<0;1,0>:q    {Compacted,I@2}
        add (1|M0)               r5.0<1>:q     r27.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,@2,$13.src}
        send.ugm (1|M0)          r11      r10  null:0  0x0            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r15      r10  null:0  0x100000            0x0240F580           {$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($3,$7,$8,$9,$10,$11,$12)
        dpas.8x8 (16|M0)         r56:d         r56:d             r37:s4            r29.0:b          {Atomic,$6.dst}
        dpas.8x8 (16|M0)         r42:d         r42:d             r37:s4            r33.0:b          {$6}
        sync.nop                             null                             {$6.src}
        send.ugm (1|M0)          r37      r6  null:0  0x0            0x0240F580           {I@2,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r29      r5  null:0  0x0            0x0240F580           {I@1,$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r33      r5  null:0  0x100000            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r25.3<1>:q    r25.3<0;1,0>:q    2:w
(W)     mov (1|M0)               r1.3<1>:hf    0x1:hf
        cmp (1|M0)    (lt)f2.1   null<1>:ud    r25.6<0;1,0>:ud   r2.14<0;1,0>:ud  {I@1}
        cmp (1|M0)    (lt)f0.0   null<1>:ud    r25.7<0;1,0>:ud   r2.15<0;1,0>:ud
(f2.1)  cmp (1|M0)    (eq)f2.1   null<1>:d     r25.7<0;1,0>:d    r2.15<0;1,0>:d
(f0.0)  sel (1|M0)               r2.6<1>:uw    r1.3<0;1,0>:uw    0x0:uw              {F@1}
(f2.1)  sel (1|M0)               r1.4<1>:uw    r1.3<0;1,0>:uw    0x0:uw
        or (1|M0)     (ne)f1.0   null<1>:uw    r1.4<0;1,0>:uw    r2.6<0;1,0>:uw   {I@1}
        sync.allwr                           ($6,$14,$15)
        dpas.8x8 (16|M0)         r56:d         r56:d             r19:s4            r11.0:b          {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r42:d         r42:d             r19:s4            r15.0:b          {$11}
(W&f1.0) jmpi                                L1712
