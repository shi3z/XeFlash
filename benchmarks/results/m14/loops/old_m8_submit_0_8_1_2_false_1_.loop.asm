        shl (1|M0)               r31.7<1>:q    r31.7<0;1,0>:q    2:w               {I@2}
        or (2|M0)                r1.2<1>:d     r33.10<1;1,0>:d   r31.12<1;1,0>:d
        add (1|M0)               r9.0<1>:q     r31.3<0;1,0>:q    r31.7<0;1,0>:q   {Compacted,I@2}
(W)     mul (1|M0)               acc0.0<1>:d   r1.2<0;1,0>:d     r31.10<0;1,0>:uw {I@2}
        macl (1|M0)              r20.0<1>:d    r1.2<0;1,0>:d     r31.5<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r1.3<0;1,0>:d     r31.8<0;1,0>:uw
        send.ugm (1|M0)          r15      r33  null:0  0x100000            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r24      r33  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r11      r9  null:0  0x0            0x0240F580           {I@4,$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        shl (1|M0)               r33.0<1>:q    r33.4<0;1,0>:q    10:w               {Compacted,$5.src}
        macl (1|M0)              r9.0<1>:d     r1.3<0;1,0>:d     r31.4<0;1,0>:d   {Compacted,$6.src}
        mul (1|M0)               acc0.0<1>:ud  r1.2<0;1,0>:ud    r31.8<0;1,0>:uw
        or (2|M0)                r4.4<1>:d     r33.10<1;1,0>:d   r32.0<1;1,0>:d
        mach (1|M0)              r23.0<1>:ud   r1.2<0;1,0>:ud    r31.4<0;1,0>:ud  {Compacted}
        add (1|M0)               r10.0<1>:q    r31.4<0;1,0>:q    r33.0<0;1,0>:q   {Compacted,I@5}
        mov (1|M0)               r22.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r4.4<0;1,0>:d     r31.10<0;1,0>:uw {I@4}
        sync.nop                             null                             {Compacted,$3.src}
        send.ugm (1|M0)          r35      r10  null:0  0x0            0x0240F580           {I@3,$7} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r39      r10  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        macl (1|M0)              r10.0<1>:d    r4.4<0;1,0>:d     r31.5<0;1,0>:d   {Compacted,$8.src}
(W)     mul (1|M0)               acc0.0<1>:d   r4.5<0;1,0>:d     r31.8<0;1,0>:uw
        macl (1|M0)              r21.0<1>:d    r4.5<0;1,0>:d     r31.4<0;1,0>:d
        mul (1|M0)               acc0.0<1>:ud  r4.4<0;1,0>:ud    r31.8<0;1,0>:uw
        mach (1|M0)              r29.0<1>:ud   r4.4<0;1,0>:ud    r31.4<0;1,0>:ud  {Compacted}
        add3 (1|M0)              r2.5<1>:d     r9.0<0;0>:d       r23.0<0;0>:d      r20.0<0>:d
        mov (1|M0)               r28.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
        mov (1|M0)               r2.4<1>:d     r22.0<0;1,0>:d                   {Compacted,I@7}
        add3 (1|M0)              r1.3<1>:d     r21.0<0;0>:d      r29.0<0;0>:d      r10.0<0>:d       {I@4}
        mov (1|M0)               r1.2<1>:d     r28.0<0;1,0>:d                   {I@3}
        shl (1|M0)               r2.2<1>:q     r2.2<0;1,0>:q     2:w               {I@3}
        shl (1|M0)               r1.1<1>:q     r1.1<0;1,0>:q     2:w               {I@2}
        add (1|M0)               r19.0<1>:q    r31.3<0;1,0>:q    r2.2<0;1,0>:q    {Compacted,I@2}
        add (1|M0)               r9.0<1>:q     r31.3<0;1,0>:q    r1.1<0;1,0>:q    {Compacted,I@2}
        send.ugm (1|M0)          r5       r34  null:0  0x0            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r43      r19  null:0  0x0            0x0240F580           {I@2,$10} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r47      r9  null:0  0x0            0x0240F580           {I@1,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r32.1<1>:q    r33.5<0;1,0>:q    4:w
(W)     mov (1|M0)               r2.6<1>:hf    0x1:hf
        cmp (1|M0)    (lt)f1.1   null<1>:ud    r32.2<0;1,0>:ud   r2.14<0;1,0>:ud  {I@1}
        cmp (1|M0)    (lt)f3.0   null<1>:ud    r32.3<0;1,0>:ud   r2.15<0;1,0>:ud
(f1.1)  cmp (1|M0)    (eq)f1.1   null<1>:d     r32.3<0;1,0>:d    r2.15<0;1,0>:d
(f3.0)  sel (1|M0)               r4.8<1>:uw    r2.6<0;1,0>:uw    0x0:uw              {F@1}
(f1.1)  sel (1|M0)               r2.7<1>:uw    r2.6<0;1,0>:uw    0x0:uw
        or (1|M0)     (ne)f1.0   null<1>:uw    r2.7<0;1,0>:uw    r4.8<0;1,0>:uw   {I@1}
        sync.allwr                           ($3,$5,$6,$9)
        dpas.8x8 (16|M0)         r66:d         r66:d             r15:s4            r11.0:b          {Atomic,$4.dst}
        dpas.8x8 (16|M0)         r54:d         r54:d             r24:s4            r5.0:b           {$3}
(W&f1.0) jmpi                                L2208
        sync.allwr                           ($3,$8,$10,$11)
        dpas.8x8 (16|M0)         r54:d         r54:d             r35:s4            r43.0:b          {Atomic,$7.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r39:s4            r47.0:b          {$7}
(W)     jmpi                                 L2656
        mul (1|M0)               acc0.0<1>:ud  r32.2<0;1,0>:ud   r31.8<0;1,0>:uw
        mach (1|M0)              r7.0<1>:ud    r32.2<0;1,0>:ud   r31.4<0;1,0>:ud  {$3.src}
        add (1|M0)               r33.5<1>:q    r33.5<0;1,0>:q    5:w
        mov (1|M0)               r6.0<1>:ud    acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r32.2<0;1,0>:d    r31.10<0;1,0>:uw
        macl (1|M0)              r8.0<1>:d     r32.2<0;1,0>:d    r31.5<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r32.3<0;1,0>:d    r31.8<0;1,0>:uw
        macl (1|M0)              r5.0<1>:d     r32.3<0;1,0>:d    r31.4<0;1,0>:d   {Compacted}
        mul (1|M0)               acc0.0<1>:ud  r33.10<0;1,0>:ud  r31.8<0;1,0>:uw  {I@6}
        mach (1|M0)              r11.0<1>:ud   r33.10<0;1,0>:ud  r31.4<0;1,0>:ud  {Compacted}
        mov (1|M0)               r34.0<1>:f    r6.0<0;1,0>:f                    {Compacted,I@7}
        add3 (1|M0)              r34.1<1>:d    r5.0<0;0>:d       r7.0<0;0>:d       r8.0<0>:d        {I@3}
        mov (1|M0)               r10.0<1>:ud   acc0.0<0;1,0>:ud                 {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r33.10<0;1,0>:d   r31.10<0;1,0>:uw
        macl (1|M0)              r12.0<1>:d    r33.10<0;1,0>:d   r31.5<0;1,0>:d   {Compacted}
(W)     mul (1|M0)               acc0.0<1>:d   r33.11<0;1,0>:d   r31.8<0;1,0>:uw
        shl (1|M0)               r34.0<1>:q    r34.0<0;1,0>:q    2:w               {Compacted,A@1}
        macl (1|M0)              r9.0<1>:d     r33.11<0;1,0>:d   r31.4<0;1,0>:d   {$11.src}
        sync.allwr                           ($3,$8,$10,$11)
        dpas.8x8 (16|M0)         r54:d         r54:d             r35:s4            r43.0:b          {Atomic,$7.dst}
        dpas.8x8 (16|M0)         r66:d         r66:d             r39:s4            r47.0:b          {$3}
        add (1|M0)               r33.0<1>:q    r31.5<0;1,0>:q    r33.0<0;1,0>:q
        add (1|M0)               r33.4<1>:q    r33.4<0;1,0>:q    1:w
        mov (1|M0)               r31.14<1>:d   r10.0<0;1,0>:d                   {I@7}
        add (1|M0)               r34.0<1>:q    r31.3<0;1,0>:q    r34.0<0;1,0>:q   {I@5}
        mov (1|M0)               r33.5<1>:q    r32.1<0;1,0>:q
        add3 (1|M0)              r31.15<1>:d   r9.0<0;0>:d       r11.0<0;0>:d      r12.0<0>:d       {I@6}
(W)     jmpi                                 L1472
