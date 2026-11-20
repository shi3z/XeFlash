        send.ugm (1|M0)          r35      r34  null:0  0x0            0x0220E580           {I@6,$10} // wr:1+0, rd:2; load.ugm.d32x32t.a64
        send.ugm (1|M0)          r37      r34  null:0  0x80000            0x0210D580           {$12} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x80]
        sync.nop                             null                             {Compacted,$7.src}
        send.ugm (1|M0)          r39      r33  null:0  0x0            0x0240F580           {I@5,$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r47      r33  null:0  0x100000            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {Compacted,$8.dst}
        sync.nop                             null                             {Compacted,$3.src}
        shr (16|M0)              r3.0<1>:ud    r43.0<1;1,0>:ud   0x18:uw              {Compacted,$2.dst}
        shl (16|M0)              r6.0<1>:d     r44.0<1;1,0>:d    8:w               {Compacted,$5.src}
        shr (16|M0)              r7.0<1>:ud    r44.0<1;1,0>:ud   0x10:uw              {Compacted}
        sync.nop                             null                             {Compacted,$9.dst}
        shl (16|M0)              r10.0<1>:d    r45.0<1;1,0>:d    16:w               {Compacted,$3.dst}
        mov (32|M0)              r8.0<1>:f     r43.0<1;1,0>:f                   {Compacted}
        shr (16|M0)              r13.0<1>:ud   r45.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r12.0<1>:d    r10.0<1;1,0>:d    r7.0<1;1,0>:d    {Compacted,I@2}
        or (16|M0)               r9.0<1>:d     r6.0<1;1,0>:d     r3.0<1;1,0>:d    {Compacted,F@1}
        and (32|M0)              r14.0<1>:w    r12.0<2;1,0>:w    4095:w               {I@2}
        and (32|M0)              r11.0<1>:w    r8.0<2;1,0>:w     4095:w               {I@2}
        shl (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0x4:uw              {Compacted}
        shl (32|M0)              r8.0<1>:d     r8.0<1;1,0>:d     4:w               {Compacted}
(W)     mov (1|M0)               r5.0<1>:f     0xFFF0000:f
        mov (32|M0)              r19.0<1>:d    r14.0<1;1,0>:uw                  {I@4}
        mov (32|M0)              r15.0<1>:d    r11.0<1;1,0>:uw                  {I@4}
        bfn.0xEA (32|M0)         r21.0<1>:ud   r19.0<1;0>:ud     r12.0<1;0>:ud     r5.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r17.0<1>:ud   r15.0<1;0>:ud     r8.0<1;0>:ud      r5.0<0>:ud       {I@2} // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
        and (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0xFFF0000:ud
        and (32|M0)              r8.0<1>:ud    r8.0<1;1,0>:ud    0xFFF0000:ud
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r17.0<1>:ud   r17.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
(W)     mov (1|M0)               r3.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r12.0<1>:ud   r1.2<0;0>:ud      r12.0<1;0>:ud     r19.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r8.0<1>:ud    r1.2<0;0>:ud      r8.0<1;0>:ud      r15.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r25.0<1>:ud   r12.0<1;0>:ud     r21.0<1;0>:ud     r3.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r23.0<1>:ud   r8.0<1;0>:ud      r17.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
(W)     mov (1|M0)               r2.3<1>:f     0x7070707:f
        and (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r17.0<1>:ud   r17.0<1;1,0>:ud   0x3F003F00:ud
        add (1|M0)               r32.1<1>:d    r32.1<0;1,0>:d    2:w
        shl (32|M0)              r25.0<1>:ud   r25.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
(W)     mov (1|M0)               r6.0<1>:f     0x70707070:f
        bfn.0xA8 (32|M0)         r21.0<1>:ud   r2.3<0;0>:ud      r21.0<1;0>:ud     r12.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r17.0<1>:ud   r2.3<0;0>:ud      r17.0<1;0>:ud     r8.0<1>:ud       {I@5} // s0&(s1|s2)
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r32.1<0;1,0>:ud   r4.10<0;1,0>:ud  {I@5}
        bfn.0xEA (32|M0)         r29.0<1>:ud   r21.0<1;0>:ud     r25.0<1;0>:ud     r6.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r27.0<1>:ud   r17.0<1;0>:ud     r23.0<1;0>:ud     r6.0<0>:ud       {I@3} // s0|s1&s2
        sync.nop                             null                             {I@1}
        sync.allwr                           ($5,$6,$7,$11)
        dpas.8x8 (16|M0)         r70:d         r70:d             r27:u4            r51.0:b          {Atomic,$4.dst}
        dpas.8x8 (16|M0)         r62:d         r62:d             r27:u4            r55.0:b          {$4}
        add (1|M0)               r32.4<1>:uq   r34.0<0;1,0>:uq   0xC0:uw
        add (1|M0)               r38.0<1>:q    r33.0<0;1,0>:q    r32.2<0;1,0>:q   {Compacted}
(W&f3.1) jmpi                                L2392
        mov (1|M0)               r34.0<1>:uq   r32.4<0;1,0>:uq                  {Compacted,@3,$12.src}
        mov (1|M0)               r33.0<1>:uq   r38.0<0;1,0>:uq                  {Compacted,@3,$14.src}
(W)     jmpi                                 L2488
        send.ugm (1|M0)          r43      r34  null:0  0xC0000            0x0220E580           {I@3,$8} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0xC0]
        send.ugm (1|M0)          r45      r34  null:0  0x140000            0x0210D580           {$9} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x140]
        sync.nop                             null                             {Compacted,$4.src}
        send.ugm (1|M0)          r51      r38  null:0  0x0            0x0240F580           {$6} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r55      r38  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r33.0<1>:q    r33.0<0;1,0>:q    r32.3<0;1,0>:q   {Compacted,@2,$14.src}
        add (1|M0)               r34.0<1>:uq   r34.0<0;1,0>:uq   0x180:uw              {$9.src}
        shr (16|M0)              r3.0<1>:ud    r35.0<1;1,0>:ud   0x18:uw              {Compacted,$10.dst}
        shl (16|M0)              r6.0<1>:d     r36.0<1;1,0>:d    8:w               {Compacted}
        shr (16|M0)              r7.0<1>:ud    r36.0<1;1,0>:ud   0x10:uw              {Compacted}
        shl (16|M0)              r8.0<1>:d     r37.0<1;1,0>:d    16:w               {Compacted,$12.dst}
        shr (16|M0)              r11.0<1>:ud   r37.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r36.0<1>:d    r6.0<1;1,0>:d     r3.0<1;1,0>:d    {Compacted,I@4}
        or (16|M0)               r10.0<1>:d    r8.0<1;1,0>:d     r7.0<1;1,0>:d    {Compacted,I@3}
        and (32|M0)              r9.0<1>:w     r35.0<2;1,0>:w    4095:w               {I@2}
        and (32|M0)              r12.0<1>:w    r10.0<2;1,0>:w    4095:w               {I@2}
        shl (32|M0)              r35.0<1>:d    r35.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0x4:uw              {Compacted}
(W)     mov (1|M0)               r5.0<1>:f     0xFFF0000:f
        mov (32|M0)              r14.0<1>:d    r9.0<1;1,0>:uw                   {I@4}
        mov (32|M0)              r19.0<1>:d    r12.0<1;1,0>:uw                  {I@4}
        bfn.0xEA (32|M0)         r16.0<1>:ud   r14.0<1;0>:ud     r35.0<1;0>:ud     r5.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r21.0<1>:ud   r19.0<1;0>:ud     r10.0<1;0>:ud     r5.0<0>:ud       {I@2} // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
        and (32|M0)              r35.0<1>:ud   r35.0<1;1,0>:ud   0xFFF0000:ud
        and (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r16.0<1>:ud   r16.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
(W)     mov (1|M0)               r3.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r35.0<1>:ud   r1.2<0;0>:ud      r35.0<1;0>:ud     r14.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r10.0<1>:ud   r1.2<0;0>:ud      r10.0<1;0>:ud     r19.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r7.0<1>:ud    r35.0<1;0>:ud     r16.0<1;0>:ud     r3.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r23.0<1>:ud   r10.0<1;0>:ud     r21.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
(W)     mov (1|M0)               r9.0<1>:f     0x7070707:f
        and (32|M0)              r16.0<1>:ud   r16.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x3F003F00:ud
        shl (32|M0)              r7.0<1>:ud    r7.0<1;1,0>:ud    0x1:uw              {Compacted,I@4}
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
(W)     mov (1|M0)               r6.0<1>:f     0x70707070:f
        bfn.0xA8 (32|M0)         r16.0<1>:ud   r9.0<0;0>:ud      r16.0<1;0>:ud     r35.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r21.0<1>:ud   r9.0<0;0>:ud      r21.0<1;0>:ud     r10.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r12.0<1>:ud   r16.0<1;0>:ud     r7.0<1;0>:ud      r6.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r14.0<1>:ud   r21.0<1;0>:ud     r23.0<1;0>:ud     r6.0<0>:ud       {I@2} // s0|s1&s2
        sync.nop                             null                             {I@1}
        sync.allwr                           ($4,$14)
        dpas.8x8 (16|M0)         r70:d         r70:d             r12:u4            r39.0:b          {Atomic,$13.dst}
        dpas.8x8 (16|M0)         r62:d         r62:d             r12:u4            r47.0:b          {$7}
(W&f3.1) jmpi                                L1648
