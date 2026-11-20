        mul (1|M0)               acc0.0<1>:ud  r33.6<0;1,0>:ud   r33.16<0;1,0>:uw {I@1}
        mach (1|M0)              r11.0<1>:ud   r33.6<0;1,0>:ud   r33.8<0;1,0>:ud  {Compacted,$2.src}
        shl (1|M0)               r1.1<1>:q     r33.4<0;1,0>:q    8:w
        mov (1|M0)               r10.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r33.6<0;1,0>:d    r33.18<0;1,0>:uw
        macl (1|M0)              r12.0<1>:d    r33.6<0;1,0>:d    r33.9<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r33.7<0;1,0>:d    r33.16<0;1,0>:uw
        macl (1|M0)              r13.0<1>:d    r33.7<0;1,0>:d    r33.8<0;1,0>:d
        mov (1|M0)               r2.4<1>:d     r10.0<0;1,0>:d                   {Compacted,I@5}
        add3 (1|M0)              r2.5<1>:d     r13.0<0;0>:d      r11.0<0;0>:d      r12.0<0>:d       {I@2}
        add (1|M0)               r3.0<1>:q     r34.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@2}
        sync.nop                             null                             {Compacted,$2.src}
        send.ugm (1|M0)          r6       r3  null:0  0x0            0x0240F580           {I@2,$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r14.0<1>:q    r35.0<0;1,0>:q    r2.2<0;1,0>:q    {I@1}
        add (1|M0)               r33.4<1>:q    r33.4<0;1,0>:q    1:w
        send.ugm (1|M0)          r15      r14  null:0  0x0            0x0240F580           {I@2,$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r19      r14  null:0  0x100000            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r25      r14  null:0  0x200000            0x0240F580           {$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r29      r14  null:0  0x300000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        cmp (1|M0)    (eq)f0.0   null<1>:d     r33.9<0;1,0>:d    r4.9<0;1,0>:d    {I@1}
(f0.0)  cmp (1|M0)    (eq)f0.0   null<1>:d     r33.8<0;1,0>:d    r4.8<0;1,0>:d
        sync.allwr                           ($7,$8,$9,$10,$11)
        dpas.8x8 (16|M0)         r60:d         r60:d             r6:s4             r15.0:b          {Atomic,$2.dst}
        dpas.8x8 (16|M0)         r52:d         r52:d             r6:s4             r19.0:b          {Atomic}
        dpas.8x8 (16|M0)         r44:d         r44:d             r6:s4             r25.0:b          {Atomic}
        dpas.8x8 (16|M0)         r36:d         r36:d             r6:s4             r29.0:b          {$2}
(W&f0.0) jmpi                                L2160
(W)     jmpi                                 L1616
