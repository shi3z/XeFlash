        add (1|M0)               r3.0<1>:q     r86.0<0;1,0>:q    r70.1<0;1,0>:q   {I@4}
        send.ugm (1|M0)          r72      r71  null:0  0x0            0x0220E580           {I@4,$0} // wr:1+0, rd:2; load.ugm.d32x32t.a64
        send.ugm (1|M0)          r74      r71  null:0  0x80000            0x0210D580           {$1} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x80]
        send.ugm (1|M0)          r76      r71  null:0  0xC0000            0x0220E580           {$15} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0xC0]
        send.ugm (1|M0)          r78      r71  null:0  0x140000            0x0210D580           {$13} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x140]
        send.ugm (1|M0)          r79      r3  null:0  0x0            0x0210C580           {I@1,$14} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.nop                             null                             {Compacted,$9.dst}
        shl (16|M0)              r6.0<1>:d     r81.0<1;1,0>:d    8:w               {Compacted,$2.dst}
        shr (16|M0)              r7.0<1>:ud    r80.0<1;1,0>:ud   0x18:uw              {Compacted}
        sync.nop                             null                             {Compacted,$10.dst}
        shl (16|M0)              r11.0<1>:d    r82.0<1;1,0>:d    16:w               {Compacted,$3.dst}
        shr (16|M0)              r12.0<1>:ud   r81.0<1;1,0>:ud   0x10:uw              {Compacted}
        sync.nop                             null                             {Compacted,$12.dst}
        shl (16|M0)              r41.0<1>:d    r84.0<1;1,0>:d    8:w               {Compacted,$4.dst}
        shr (16|M0)              r42.0<1>:ud   r83.0<1;1,0>:ud   0x18:uw              {Compacted}
        sync.nop                             null                             {Compacted,$11.dst}
        shl (16|M0)              r45.0<1>:d    r85.0<1;1,0>:d    16:w               {Compacted,$5.dst}
        shr (16|M0)              r46.0<1>:ud   r84.0<1;1,0>:ud   0x10:uw              {Compacted}
        mov (32|M0)              r9.0<1>:f     r80.0<1;1,0>:f                   {Compacted}
        mov (32|M0)              r43.0<1>:f    r83.0<1;1,0>:f                   {Compacted}
        shr (16|M0)              r14.0<1>:ud   r82.0<1;1,0>:ud   0x8:uw              {Compacted}
        shr (16|M0)              r48.0<1>:ud   r85.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r13.0<1>:d    r11.0<1;1,0>:d    r12.0<1;1,0>:d   {Compacted,I@7}
        or (16|M0)               r47.0<1>:d    r45.0<1;1,0>:d    r46.0<1;1,0>:d   {Compacted,I@4}
        or (16|M0)               r10.0<1>:d    r6.0<1;1,0>:d     r7.0<1;1,0>:d    {Compacted,F@2}
        or (16|M0)               r44.0<1>:d    r41.0<1;1,0>:d    r42.0<1;1,0>:d   {Compacted,F@1}
        and (32|M0)              r16.0<1>:w    r13.0<2;1,0>:w    4095:w               {I@4}
        and (32|M0)              r50.0<1>:w    r47.0<2;1,0>:w    4095:w               {I@4}
        and (32|M0)              r15.0<1>:w    r9.0<2;1,0>:w     4095:w               {I@4}
        and (32|M0)              r49.0<1>:w    r43.0<2;1,0>:w    4095:w               {I@4}
        shl (32|M0)              r13.0<1>:ud   r13.0<1;1,0>:ud   0x4:uw              {Compacted}
        shl (32|M0)              r47.0<1>:ud   r47.0<1;1,0>:ud   0x4:uw              {Compacted}
        shl (32|M0)              r9.0<1>:d     r9.0<1;1,0>:d     4:w               {Compacted}
        shl (32|M0)              r43.0<1>:d    r43.0<1;1,0>:d    4:w               {Compacted}
(W)     mov (1|M0)               r26.0<1>:f    0xFFF0000:f
        mov (32|M0)              r19.0<1>:d    r16.0<1;1,0>:uw                  {I@7}
        mov (32|M0)              r53.0<1>:d    r50.0<1;1,0>:uw                  {I@7}
        mov (32|M0)              r17.0<1>:d    r15.0<1;1,0>:uw                  {I@7}
        mov (32|M0)              r51.0<1>:d    r49.0<1;1,0>:uw                  {I@7}
        and (32|M0)              r24.0<1>:ud   r13.0<1;1,0>:ud   0xFFF0000:ud              {I@7}
        and (32|M0)              r58.0<1>:ud   r47.0<1;1,0>:ud   0xFFF0000:ud              {I@7}
        and (32|M0)              r22.0<1>:d    r9.0<1;1,0>:d     268369920:d               {I@7}
        and (32|M0)              r56.0<1>:d    r43.0<1;1,0>:d    268369920:d               {I@7}
        bfn.0xEA (32|M0)         r13.0<1>:ud   r19.0<1;0>:ud     r13.0<1;0>:ud     r26.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r47.0<1>:ud   r53.0<1;0>:ud     r47.0<1;0>:ud     r26.0<0>:ud      {I@7} // s0|s1&s2
        bfn.0xEA (32|M0)         r9.0<1>:ud    r17.0<1;0>:ud     r9.0<1;0>:ud      r26.0<0>:ud      {I@7} // s0|s1&s2
        bfn.0xEA (32|M0)         r43.0<1>:ud   r51.0<1;0>:ud     r43.0<1;0>:ud     r26.0<0>:ud      {I@7} // s0|s1&s2
(W)     mov (1|M0)               r27.0<1>:f    5.785725e-39:f                               {$6.src}
        shl (32|M0)              r13.0<1>:ud   r13.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r47.0<1>:ud   r47.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x2:uw              {Compacted,I@4}
        shl (32|M0)              r43.0<1>:ud   r43.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
(W)     mov (1|M0)               r33.0<1>:f    5.009613e-01:f
        bfn.0xA8 (32|M0)         r22.0<1>:ud   r27.0<0;0>:ud     r22.0<1;0>:ud     r17.0<1>:ud      {F@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r24.0<1>:ud   r27.0<0;0>:ud     r24.0<1;0>:ud     r19.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r56.0<1>:ud   r27.0<0;0>:ud     r56.0<1;0>:ud     r51.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r58.0<1>:ud   r27.0<0;0>:ud     r58.0<1;0>:ud     r53.0<1>:ud      // s0&(s1|s2)
        and (32|M0)              r31.0<1>:ud   r13.0<1;1,0>:ud   0x3F003F00:ud              {I@7}
        and (32|M0)              r63.0<1>:ud   r47.0<1;1,0>:ud   0x3F003F00:ud              {I@7}
        and (32|M0)              r29.0<1>:ud   r9.0<1;1,0>:ud    0x3F003F00:ud              {I@7}
        and (32|M0)              r61.0<1>:ud   r43.0<1;1,0>:ud   0x3F003F00:ud              {I@7}
        bfn.0xEA (32|M0)         r13.0<1>:ud   r24.0<1;0>:ud     r13.0<1;0>:ud     r33.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r47.0<1>:ud   r58.0<1;0>:ud     r47.0<1;0>:ud     r33.0<0>:ud      {I@6} // s0|s1&s2
        bfn.0xEA (32|M0)         r9.0<1>:ud    r22.0<1;0>:ud     r9.0<1;0>:ud      r33.0<0>:ud      // s0|s1&s2
        bfn.0xEA (32|M0)         r43.0<1>:ud   r56.0<1;0>:ud     r43.0<1;0>:ud     r33.0<0>:ud      // s0|s1&s2
(W)     mov (1|M0)               r34.0<1>:f    0x7070707:f
        add (1|M0)               r5.1<1>:d     r5.1<0;1,0>:d     4:w
        shl (32|M0)              r13.0<1>:ud   r13.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
        shl (32|M0)              r47.0<1>:ud   r47.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x1:uw              {Compacted,I@5}
        shl (32|M0)              r43.0<1>:ud   r43.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
(W)     mov (1|M0)               r36.0<1>:f    0x70707070:f
        bfn.0xA8 (32|M0)         r29.0<1>:ud   r34.0<0;0>:ud     r29.0<1;0>:ud     r22.0<1>:ud      {F@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r31.0<1>:ud   r34.0<0;0>:ud     r31.0<1;0>:ud     r24.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r61.0<1>:ud   r34.0<0;0>:ud     r61.0<1;0>:ud     r56.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r63.0<1>:ud   r34.0<0;0>:ud     r63.0<1;0>:ud     r58.0<1>:ud      // s0&(s1|s2)
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r5.1<0;1,0>:ud    r4.10<0;1,0>:ud  {I@7}
        bfn.0xEA (32|M0)         r37.0<1>:ud   r29.0<1;0>:ud     r9.0<1;0>:ud      r36.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r39.0<1>:ud   r31.0<1;0>:ud     r13.0<1;0>:ud     r36.0<0>:ud      {I@5} // s0|s1&s2
        bfn.0xEA (32|M0)         r65.0<1>:ud   r61.0<1;0>:ud     r43.0<1;0>:ud     r36.0<0>:ud      {I@5} // s0|s1&s2
        bfn.0xEA (32|M0)         r67.0<1>:ud   r63.0<1;0>:ud     r47.0<1;0>:ud     r36.0<0>:ud      {I@5} // s0|s1&s2
        sync.nop                             null                             {Compacted,I@3}
        sync.nop                             null                             {Compacted,$8.dst}
        dpas.8x1 (16|M0)         r88:d         r88:d             r37:u4            r89.0:b          {$6}
        sync.nop                             null                             {I@1}
        dpas.8x1 (16|M0)         r94:d         r94:d             r65:u4            r87.0:b          {$7}
        send.ugm (1|M0)          r75      r86  null:0  0x0            0x0210C580           {$2} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r70.2<1>:uq   r71.0<0;1,0>:uq   0xC0:uw
        add (1|M0)               r70.3<1>:uq   r71.0<0;1,0>:uq   384:w
        add (1|M0)               r86.0<1>:q    r3.0<0;1,0>:q     r70.1<0;1,0>:q   {Compacted,$2.src}
(W&f3.1) jmpi                                L2768
        mov (1|M0)               r71.0<1>:uq   r70.3<0;1,0>:uq                  {Compacted,@3,$13.src}
(W)     jmpi                                 L2920
        sync.nop                             null                             {Compacted,$6.src}
        send.ugm (1|M0)          r89      r86  null:0  0x0            0x0210C580           {I@4,$8} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r86.0<1>:q    r86.0<0;1,0>:q    r70.1<0;1,0>:q   {Compacted,$8.src}
        send.ugm (1|M0)          r80      r71  null:0  0x180000            0x0220E580           {I@3,$9} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0x180]
        send.ugm (1|M0)          r82      r71  null:0  0x200000            0x0210D580           {$10} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x200]
        send.ugm (1|M0)          r83      r71  null:0  0x240000            0x0220E580           {$12} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0x240]
        send.ugm (1|M0)          r85      r71  null:0  0x2C0000            0x0210D580           {$11} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x2C0]
        sync.nop                             null                             {$7.src}
        send.ugm (1|M0)          r87      r86  null:0  0x0            0x0210C580           {I@1,$14} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r71.0<1>:uq   r70.2<0;1,0>:uq   0x240:uw              {$11.src}
        add (1|M0)               r86.0<1>:q    r86.0<0;1,0>:q    r70.1<0;1,0>:q   {Compacted,$14.src}
        sync.nop                             null                             {Compacted,$14.src}
        shl (16|M0)              r3.0<1>:d     r73.0<1;1,0>:d    8:w               {Compacted,$0.dst}
        shr (16|M0)              r6.0<1>:ud    r72.0<1;1,0>:ud   0x18:uw              {Compacted}
        shr (16|M0)              r7.0<1>:ud    r73.0<1;1,0>:ud   0x10:uw              {Compacted}
        shl (16|M0)              r8.0<1>:d     r74.0<1;1,0>:d    16:w               {Compacted,$1.dst}
        sync.nop                             null                             {Compacted,$6.src}
        shl (16|M0)              r37.0<1>:d    r77.0<1;1,0>:d    8:w               {Compacted,$15.dst}
        shr (16|M0)              r38.0<1>:ud   r76.0<1;1,0>:ud   0x18:uw              {Compacted}
        shr (16|M0)              r39.0<1>:ud   r77.0<1;1,0>:ud   0x10:uw              {Compacted}
        shl (16|M0)              r40.0<1>:d    r78.0<1;1,0>:d    16:w               {Compacted,$13.dst}
        shr (16|M0)              r10.0<1>:ud   r74.0<1;1,0>:ud   0x8:uw              {Compacted}
        shr (16|M0)              r42.0<1>:ud   r78.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r73.0<1>:d    r3.0<1;1,0>:d     r6.0<1;1,0>:d    {Compacted,I@7}
        or (16|M0)               r9.0<1>:d     r8.0<1;1,0>:d     r7.0<1;1,0>:d    {Compacted,I@7}
        or (16|M0)               r77.0<1>:d    r37.0<1;1,0>:d    r38.0<1;1,0>:d   {Compacted,I@7}
        or (16|M0)               r41.0<1>:d    r40.0<1;1,0>:d    r39.0<1;1,0>:d   {I@6}
        and (32|M0)              r11.0<1>:w    r72.0<2;1,0>:w    4095:w               {I@4}
        and (32|M0)              r12.0<1>:w    r9.0<2;1,0>:w     4095:w               {I@4}
        and (32|M0)              r43.0<1>:w    r76.0<2;1,0>:w    4095:w               {I@4}
        and (32|M0)              r44.0<1>:w    r41.0<2;1,0>:w    4095:w               {I@4}
        shl (32|M0)              r72.0<1>:d    r72.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x4:uw              {Compacted}
        shl (32|M0)              r76.0<1>:d    r76.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r41.0<1>:ud   r41.0<1;1,0>:ud   0x4:uw              {Compacted}
(W)     mov (1|M0)               r22.0<1>:f    0xFFF0000:f
        mov (32|M0)              r13.0<1>:d    r11.0<1;1,0>:uw                  {I@7}
        mov (32|M0)              r15.0<1>:d    r12.0<1;1,0>:uw                  {I@7}
        mov (32|M0)              r45.0<1>:d    r43.0<1;1,0>:uw                  {I@7}
        mov (32|M0)              r47.0<1>:d    r44.0<1;1,0>:uw                  {I@7}
        and (32|M0)              r18.0<1>:d    r72.0<1;1,0>:d    268369920:d               {I@7}
        and (32|M0)              r20.0<1>:ud   r9.0<1;1,0>:ud    0xFFF0000:ud              {I@7}
        and (32|M0)              r50.0<1>:d    r76.0<1;1,0>:d    268369920:d               {I@7}
        and (32|M0)              r52.0<1>:ud   r41.0<1;1,0>:ud   0xFFF0000:ud              {I@7}
        bfn.0xEA (32|M0)         r72.0<1>:ud   r13.0<1;0>:ud     r72.0<1;0>:ud     r22.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r9.0<1>:ud    r15.0<1;0>:ud     r9.0<1;0>:ud      r22.0<0>:ud      {I@7} // s0|s1&s2
        bfn.0xEA (32|M0)         r76.0<1>:ud   r45.0<1;0>:ud     r76.0<1;0>:ud     r22.0<0>:ud      {I@7} // s0|s1&s2
        bfn.0xEA (32|M0)         r41.0<1>:ud   r47.0<1;0>:ud     r41.0<1;0>:ud     r22.0<0>:ud      {I@7} // s0|s1&s2
(W)     mov (1|M0)               r23.0<1>:f    5.785725e-39:f
        shl (32|M0)              r72.0<1>:ud   r72.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x2:uw              {Compacted,I@4}
        shl (32|M0)              r76.0<1>:ud   r76.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r41.0<1>:ud   r41.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
(W)     mov (1|M0)               r29.0<1>:f    5.009613e-01:f
        bfn.0xA8 (32|M0)         r18.0<1>:ud   r23.0<0;0>:ud     r18.0<1;0>:ud     r13.0<1>:ud      {F@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r20.0<1>:ud   r23.0<0;0>:ud     r20.0<1;0>:ud     r15.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r50.0<1>:ud   r23.0<0;0>:ud     r50.0<1;0>:ud     r45.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r52.0<1>:ud   r23.0<0;0>:ud     r52.0<1;0>:ud     r47.0<1>:ud      // s0&(s1|s2)
        and (32|M0)              r25.0<1>:ud   r72.0<1;1,0>:ud   0x3F003F00:ud              {I@7}
        and (32|M0)              r27.0<1>:ud   r9.0<1;1,0>:ud    0x3F003F00:ud              {I@7}
        and (32|M0)              r55.0<1>:ud   r76.0<1;1,0>:ud   0x3F003F00:ud              {I@7}
        and (32|M0)              r57.0<1>:ud   r41.0<1;1,0>:ud   0x3F003F00:ud              {I@7}
        bfn.0xEA (32|M0)         r72.0<1>:ud   r18.0<1;0>:ud     r72.0<1;0>:ud     r29.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r9.0<1>:ud    r20.0<1;0>:ud     r9.0<1;0>:ud      r29.0<0>:ud      {I@7} // s0|s1&s2
        bfn.0xEA (32|M0)         r76.0<1>:ud   r50.0<1;0>:ud     r76.0<1;0>:ud     r29.0<0>:ud      {I@7} // s0|s1&s2
        bfn.0xEA (32|M0)         r41.0<1>:ud   r52.0<1;0>:ud     r41.0<1;0>:ud     r29.0<0>:ud      {I@7} // s0|s1&s2
(W)     mov (1|M0)               r30.0<1>:f    0x7070707:f
        shl (32|M0)              r72.0<1>:ud   r72.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x1:uw              {Compacted,I@4}
        shl (32|M0)              r76.0<1>:ud   r76.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
        shl (32|M0)              r41.0<1>:ud   r41.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
(W)     mov (1|M0)               r32.0<1>:f    0x70707070:f
        bfn.0xA8 (32|M0)         r25.0<1>:ud   r30.0<0;0>:ud     r25.0<1;0>:ud     r18.0<1>:ud      {F@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r27.0<1>:ud   r30.0<0;0>:ud     r27.0<1;0>:ud     r20.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r55.0<1>:ud   r30.0<0;0>:ud     r55.0<1;0>:ud     r50.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r57.0<1>:ud   r30.0<0;0>:ud     r57.0<1;0>:ud     r52.0<1>:ud      // s0&(s1|s2)
        bfn.0xEA (32|M0)         r33.0<1>:ud   r25.0<1;0>:ud     r72.0<1;0>:ud     r32.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r35.0<1>:ud   r27.0<1;0>:ud     r9.0<1;0>:ud      r32.0<0>:ud      {I@4} // s0|s1&s2
        bfn.0xEA (32|M0)         r59.0<1>:ud   r55.0<1;0>:ud     r76.0<1;0>:ud     r32.0<0>:ud      {I@4} // s0|s1&s2
        bfn.0xEA (32|M0)         r61.0<1>:ud   r57.0<1;0>:ud     r41.0<1;0>:ud     r32.0<0>:ud      {I@4} // s0|s1&s2
        sync.nop                             null                             {I@3}
        sync.allwr                           ($2,$6)
        dpas.8x1 (16|M0)         r88:d         r88:d             r33:u4            r75.0:b          {$13}
        sync.nop                             null                             {I@1}
        sync.allwr                           ($7,$14)
        dpas.8x1 (16|M0)         r94:d         r94:d             r59:u4            r79.0:b          {$15}
(W&f3.1) jmpi                                L1568
