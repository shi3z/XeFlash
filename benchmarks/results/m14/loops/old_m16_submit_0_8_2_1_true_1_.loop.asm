        or (2|M0)                r1.2<1>:d     r17.8<1;1,0>:d    r17.4<1;1,0>:d   {I@1}
        add (1|M0)               r17.4<1>:q    r17.4<0;1,0>:q    2:w
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r17.14<0;1,0>:uw {I@2}
        macl (1|M0)              r6.0<1>:d     r1.2<0;1,0>:d     r17.7<0;1,0>:d   {Compacted,$1.src}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r17.12<0;1,0>:uw
        macl (1|M0)              r7.0<1>:d     r1.3<0;1,0>:d     r17.6<0;1,0>:d   {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r17.12<0;1,0>:uw
        mach (1|M0)              r9.0<1>:ud    r1.2<0;1,0>:ud    r17.6<0;1,0>:ud
        shl (1|M0)               r1.2<1>:q     r1.1<0;1,0>:q     8:w
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
        add3 (1|M0)              r2.5<1>:d     r7.0<0;0>:d       r9.0<0;0>:d       r6.0<0>:d        {I@3}
        mov (1|M0)               r2.4<1>:d     r8.0<0;1,0>:d                    {Compacted,I@2}
        sync.nop                             null                             {Compacted,$4.src}
        add (1|M0)               r5.0<1>:q     r18.0<0;1,0>:q    r1.2<0;1,0>:q    {Compacted,$15.src}
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@2}
        sync.nop                             null                             {Compacted,$9.src}
        send.ugm (1|M0)          r37      r5  null:0  0x0            0x0240F580           {I@2,$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r10.0<1>:q    r19.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,@1,$11.src}
        add (1|M0)               r5.0<1>:q     r20.0<0;1,0>:q    r2.2<0;1,0>:q    {$5.src}
        send.ugm (1|M0)          r45      r10  null:0  0x0            0x0240F580           {I@2,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r49      r10  null:0  0x100000            0x0240F580           {$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r57      r5  null:0  0x0            0x0240F580           {I@1,$3} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r61      r5  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        cmp (1|M0)    (eq)f2.0   null<1>:d     r17.9<0;1,0>:d    r2.15<0;1,0>:d
        sync.allwr                           ($0,$1,$2,$4,$8,$9,$10,$11,$12,$14,$15)
        dpas.8x8 (16|M0)         r90:d         r90:d             r77:s4            r69.0:b          {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r82:d         r82:d             r77:s4            r73.0:b          {Atomic}
        dpas.8x8 (16|M0)         r106:d        r106:d            r77:s4            r53.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r77:s4            r65.0:ub         {$13}
(f2.0)  cmp (1|M0)    (lt)f2.0   null<1>:ud    r17.8<0;1,0>:ud   r2.14<0;1,0>:ud
(~f2.0) cmp (1|M0)    (lt)f2.0   null<1>:ud    r17.9<0;1,0>:ud   r2.15<0;1,0>:ud
(W&~f2.0) jmpi                               L2768
(W)     mul (1|M0)               acc0.0<1>:d   r17.8<0;1,0>:d    r17.14<0;1,0>:uw
        macl (1|M0)              r6.0<1>:d     r17.8<0;1,0>:d    r17.7<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r17.9<0;1,0>:d    r17.12<0;1,0>:uw
        macl (1|M0)              r7.0<1>:d     r17.9<0;1,0>:d    r17.6<0;1,0>:d   {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r17.8<0;1,0>:ud   r17.12<0;1,0>:uw
        mach (1|M0)              r9.0<1>:ud    r17.8<0;1,0>:ud   r17.6<0;1,0>:ud  {Compacted}
        shl (1|M0)               r1.1<1>:q     r17.4<0;1,0>:q    8:w
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
        add3 (1|M0)              r2.5<1>:d     r7.0<0;0>:d       r9.0<0;0>:d       r6.0<0>:d        {I@3}
        mov (1|M0)               r2.4<1>:d     r8.0<0;1,0>:d                    {Compacted,I@2}
        add (1|M0)               r5.0<1>:q     r18.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,$8.src}
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@2}
        sync.nop                             null                             {Compacted,$13.src}
        send.ugm (1|M0)          r77      r5  null:0  0x0            0x0240F580           {I@2,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r10.0<1>:q    r19.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,@1,$7.src}
        add (1|M0)               r5.0<1>:q     r20.0<0;1,0>:q    r2.2<0;1,0>:q    {$10.src}
        send.ugm (1|M0)          r69      r10  null:0  0x0            0x0240F580           {I@2,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r73      r10  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r53      r5  null:0  0x0            0x0240F580           {I@1,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r65      r5  null:0  0x100000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.allwr                           ($3,$6,$7,$8,$13)
        dpas.8x8 (16|M0)         r90:d         r90:d             r37:s4            r45.0:b          {Atomic,$5.dst}
        dpas.8x8 (16|M0)         r82:d         r82:d             r37:s4            r49.0:b          {Atomic}
        dpas.8x8 (16|M0)         r106:d        r106:d            r37:s4            r57.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r98:d         r98:d             r37:s4            r61.0:ub         {$9}
(W&f2.0) jmpi                                L2064
