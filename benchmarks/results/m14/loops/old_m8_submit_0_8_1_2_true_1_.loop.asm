        shl (1|M0)               r38.7<1>:q    r38.7<0;1,0>:q    2:w               {I@7}
        shl (1|M0)               r38.5<1>:q    r38.5<0;1,0>:q    2:w               {I@2}
        or (2|M0)                r1.2<1>:d     r39.6<1;1,0>:d    r38.12<1;1,0>:d
        add (1|M0)               r6.0<1>:q     r40.0<0;1,0>:q    r38.7<0;1,0>:q   {Compacted,I@3}
        add (1|M0)               r11.0<1>:q    r41.0<0;1,0>:q    r38.5<0;1,0>:q   {Compacted,I@3}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r38.10<0;1,0>:uw {I@3}
        send.ugm (1|M0)          r17      r6  null:0  0x0            0x0240F580           {I@3,$1} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        macl (1|M0)              r6.0<1>:d     r1.2<0;1,0>:d     r38.5<0;1,0>:d   {$1.src}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r38.8<0;1,0>:uw
        send.ugm (1|M0)          r13      r11  null:0  0x0            0x0240F580           {I@4,$2} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        macl (1|M0)              r11.0<1>:d    r1.3<0;1,0>:d     r38.4<0;1,0>:d   {Compacted,$2.src}
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r38.8<0;1,0>:uw
        or (2|M0)                r4.6<1>:d     r39.6<1;1,0>:d    r39.4<1;1,0>:d
        mach (1|M0)              r35.0<1>:ud   r1.2<0;1,0>:ud    r38.4<0;1,0>:ud  {Compacted}
        send.ugm (1|M0)          r25      r42  null:0  0x100000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        mov (1|M0)               r34.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.6<0;1,0>:d     r38.10<0;1,0>:uw {I@3}
        macl (1|M0)              r36.0<1>:d    r4.6<0;1,0>:d     r38.5<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.7<0;1,0>:d     r38.8<0;1,0>:uw
        add3 (1|M0)              r2.5<1>:d     r11.0<0;0>:d      r35.0<0;0>:d      r6.0<0>:d        {I@5}
        macl (1|M0)              r6.0<1>:d     r4.7<0;1,0>:d     r38.4<0;1,0>:d
        mul (1|M0)               acc0.0<1>:ud  r4.6<0;1,0>:ud    r38.8<0;1,0>:uw
        mach (1|M0)              r35.0<1>:ud   r4.6<0;1,0>:ud    r38.4<0;1,0>:ud
        send.ugm (1|M0)          r29      r42  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r5.0<1>:q     r41.0<0;1,0>:q    r38.7<0;1,0>:q   {Compacted}
        mov (1|M0)               r2.4<1>:d     r34.0<0;1,0>:d                   {Compacted,I@7}
        shl (1|M0)               r42.0<1>:q    r39.1<0;1,0>:q    10:w               {Compacted,$5.src}
        mov (1|M0)               r34.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
        send.ugm (1|M0)          r7       r5  null:0  0x0            0x0240F580           {I@4,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add3 (1|M0)              r1.3<1>:d     r6.0<0;0>:d       r35.0<0;0>:d      r36.0<0>:d
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@4}
        add (1|M0)               r5.0<1>:q     r38.3<0;1,0>:q    r42.0<0;1,0>:q   {Compacted,@4,$6.src}
        mov (1|M0)               r1.2<1>:d     r34.0<0;1,0>:d                   {Compacted,I@4}
        sync.allrd                           ($0,$9)
        send.ugm (1|M0)          r43      r5  null:0  0x0            0x0240F580           {I@2,$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        sync.nop                             null                             {Compacted,$15.src}
        send.ugm (1|M0)          r47      r5  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r12.0<1>:q    r40.0<0;1,0>:q    r38.5<0;1,0>:q   {Compacted}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        add (1|M0)               r5.0<1>:q     r41.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,$8.src}
        send.ugm (1|M0)          r21      r12  null:0  0x0            0x0240F580           {I@3,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r55      r5  null:0  0x0            0x0240F580           {I@1,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r11.0<1>:q    r40.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted}
        add (1|M0)               r12.0<1>:q    r40.0<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,$10.src}
        add (1|M0)               r5.0<1>:q     r41.0<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,$11.src}
        send.ugm (1|M0)          r59      r11  null:0  0x0            0x0240F580           {I@3,$12} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r51      r12  null:0  0x0            0x0240F580           {I@2,$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r67      r5  null:0  0x0            0x0240F580           {I@1,$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r39.4<1>:q    r39.3<0;1,0>:q    4:w
(W)     mov (1|M0)               r2.6<1>:hf    0x1:hf
        cmp (1|M0)    (lt)f2.1   null<1>:ud    r39.8<0;1,0>:ud   r2.14<0;1,0>:ud  {I@1}
        cmp (1|M0)    (lt)f0.0   null<1>:ud    r39.9<0;1,0>:ud   r2.15<0;1,0>:ud
(f2.1)  cmp (1|M0)    (eq)f2.1   null<1>:d     r39.9<0;1,0>:d    r2.15<0;1,0>:d
(f0.0)  sel (1|M0)               r1.4<1>:uw    r2.6<0;1,0>:uw    0x0:uw              {F@1}
(f2.1)  sel (1|M0)               r1.3<1>:uw    r2.6<0;1,0>:uw    0x0:uw
        or (1|M0)     (ne)f1.0   null<1>:uw    r1.3<0;1,0>:uw    r1.4<0;1,0>:uw   {I@1}
        sync.allwr                           ($0,$1,$2,$4,$5,$6,$10,$15)
        dpas.8x8 (16|M0)         r96:d         r96:d             r29:s4            r17.0:b          {Atomic,$9.dst}
        dpas.8x8 (16|M0)         r72:d         r72:d             r29:s4            r7.0:ub          {Atomic}
        dpas.8x8 (16|M0)         r108:d        r108:d            r25:s4            r21.0:b          {Atomic}
        dpas.8x8 (16|M0)         r82:d         r82:d             r25:s4            r13.0:ub         {$9}
(W&~f1.0) jmpi                               L3568
(W)     mul (1|M0)               acc0.0<1>:d   r39.8<0;1,0>:d    r38.10<0;1,0>:uw
        macl (1|M0)              r6.0<1>:d     r39.8<0;1,0>:d    r38.5<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r39.9<0;1,0>:d    r38.8<0;1,0>:uw
        macl (1|M0)              r5.0<1>:d     r39.9<0;1,0>:d    r38.4<0;1,0>:d   {Compacted,$14.src}
        mul (1|M0)               acc0.0<1>:ud  r39.8<0;1,0>:ud   r38.8<0;1,0>:uw
        add (1|M0)               r39.3<1>:q    r39.3<0;1,0>:q    5:w
        mach (1|M0)              r9.0<1>:ud    r39.8<0;1,0>:ud   r38.4<0;1,0>:ud  {$9.src}
        sync.allwr                           ($9,$11,$13)
        dpas.8x8 (16|M0)         r96:d         r96:d             r43:s4            r51.0:b          {Atomic,$7.dst}
        dpas.8x8 (16|M0)         r72:d         r72:d             r43:s4            r55.0:ub         {$0}
        mov (1|M0)               r8.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r39.6<0;1,0>:d    r38.10<0;1,0>:uw {I@3}
        macl (1|M0)              r10.0<1>:d    r39.6<0;1,0>:d    r38.5<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r39.7<0;1,0>:d    r38.8<0;1,0>:uw
        macl (1|M0)              r7.0<1>:d     r39.7<0;1,0>:d    r38.4<0;1,0>:d
        mul (1|M0)               acc0.0<1>:ud  r39.6<0;1,0>:ud   r38.8<0;1,0>:uw
        mach (1|M0)              r13.0<1>:ud   r39.6<0;1,0>:ud   r38.4<0;1,0>:ud
        sync.allwr                           ($12,$14)
        dpas.8x8 (16|M0)         r108:d        r108:d            r47:s4            r59.0:b          {Atomic,$8.dst}
        dpas.8x8 (16|M0)         r82:d         r82:d             r47:s4            r67.0:ub         {$15}
        mov (1|M0)               r12.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
        add (1|M0)               r42.0<1>:q    r38.4<0;1,0>:q    r42.0<0;1,0>:q   {Compacted}
        add (1|M0)               r39.1<1>:q    r39.1<0;1,0>:q    1:w
        add3 (1|M0)              r38.15<1>:d   r5.0<0;0>:d       r9.0<0;0>:d       r6.0<0>:d        {I@7}
        mov (1|M0)               r38.14<1>:d   r8.0<0;1,0>:d                    {I@7}
        mov (1|M0)               r39.3<1>:q    r39.4<0;1,0>:q
        add3 (1|M0)              r38.11<1>:d   r7.0<0;0>:d       r13.0<0;0>:d      r10.0<0>:d       {I@7}
        mov (1|M0)               r38.10<1>:d   r12.0<0;1,0>:d                   {I@7}
(W)     jmpi                                 L2304
