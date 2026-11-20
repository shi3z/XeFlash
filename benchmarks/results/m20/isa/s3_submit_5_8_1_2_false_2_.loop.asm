        send.ugm (1|M0)          r39      r38  null:0  0x0            0x0220E580           {I@4,$9} // wr:1+0, rd:2; load.ugm.d32x32t.a64
        send.ugm (1|M0)          r41      r38  null:0  0x80000            0x0210D580           {$1} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x80]
        send.ugm (1|M0)          r47      r63  null:0  0x0            0x0240F580           {I@3,$13} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r42      r38  null:0  0xC0000            0x0220E580           {$0} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0xC0]
        send.ugm (1|M0)          r44      r38  null:0  0x140000            0x0210D580           {$15} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x140]
        sync.nop                             null                             {Compacted,$14.dst}
        sync.nop                             null                             {Compacted,$6.src}
        shr (16|M0)              r6.0<1>:ud    r45.0<1;1,0>:ud   0x18:uw              {Compacted,$2.dst}
        shl (16|M0)              r7.0<1>:d     r46.0<1;1,0>:d    8:w               {Compacted}
        mov (32|M0)              r8.0<1>:f     r45.0<1;1,0>:f                   {Compacted}
        shr (16|M0)              r10.0<1>:ud   r46.0<1;1,0>:ud   0x10:uw              {Compacted}
        sync.nop                             null                             {Compacted,$10.dst}
        shl (16|M0)              r11.0<1>:d    r55.0<1;1,0>:d    16:w               {Compacted,$3.dst}
        or (16|M0)               r9.0<1>:d     r7.0<1;1,0>:d     r6.0<1;1,0>:d    {Compacted,A@1}
        add (1|M0)               r3.0<1>:q     r63.0<0;1,0>:q    r37.2<0;1,0>:q   {Compacted,$5.src}
        shr (16|M0)              r13.0<1>:ud   r55.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r12.0<1>:d    r11.0<1;1,0>:d    r10.0<1;1,0>:d   {Compacted,I@4}
        and (32|M0)              r14.0<1>:w    r8.0<2;1,0>:w     4095:w               {I@4}
        shl (32|M0)              r8.0<1>:d     r8.0<1;1,0>:d     4:w               {Compacted}
        send.ugm (1|M0)          r51      r3  null:0  0x0            0x0240F580           {I@5,$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r63.0<1>:q    r3.0<0;1,0>:q     r37.2<0;1,0>:q   {Compacted,$13.src}
        and (32|M0)              r15.0<1>:w    r12.0<2;1,0>:w    4095:w               {I@4}
        mov (32|M0)              r17.0<1>:d    r14.0<1;1,0>:uw                  {I@4}
        sync.nop                             null                             {Compacted,I@3}
(W)     mov (1|M0)               r3.0<1>:f     0xFFF0000:f                               {$11.src}
        shl (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0x4:uw              {Compacted}
        mov (32|M0)              r21.0<1>:d    r15.0<1;1,0>:uw                  {I@3}
        bfn.0xEA (32|M0)         r19.0<1>:ud   r17.0<1;0>:ud     r8.0<1;0>:ud      r3.0<0>:ud       {A@1} // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
        and (32|M0)              r8.0<1>:ud    r8.0<1;1,0>:ud    0xFFF0000:ud
        bfn.0xEA (32|M0)         r23.0<1>:ud   r21.0<1;0>:ud     r12.0<1;0>:ud     r3.0<0>:ud       {I@3} // s0|s1&s2
        shl (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x2:uw              {I@3}
(W)     mov (1|M0)               r5.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r8.0<1>:ud    r1.2<0;0>:ud      r8.0<1;0>:ud      r17.0<1>:ud      {A@2} // s0&(s1|s2)
        and (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x2:uw              {I@4}
        bfn.0xEA (32|M0)         r25.0<1>:ud   r8.0<1;0>:ud      r19.0<1;0>:ud     r5.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xA8 (32|M0)         r12.0<1>:ud   r1.2<0;0>:ud      r12.0<1;0>:ud     r21.0<1>:ud      {I@3} // s0&(s1|s2)
(W)     mov (1|M0)               r1.3<1>:f     0x7070707:f
        and (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x3F003F00:ud
        bfn.0xEA (32|M0)         r27.0<1>:ud   r12.0<1;0>:ud     r23.0<1;0>:ud     r5.0<0>:ud       {I@2} // s0|s1&s2
        bfn.0xA8 (32|M0)         r19.0<1>:ud   r1.3<0;0>:ud      r19.0<1;0>:ud     r8.0<1>:ud       {A@1} // s0&(s1|s2)
        and (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x3F003F00:ud
        sync.nop                             null                             {Compacted,$12.dst}
        shr (16|M0)              r7.0<1>:ud    r56.0<1;1,0>:ud   0x18:uw              {Compacted,$4.dst}
        shl (16|M0)              r10.0<1>:d    r57.0<1;1,0>:d    8:w               {Compacted}
        shr (16|M0)              r11.0<1>:ud   r57.0<1;1,0>:ud   0x10:uw              {Compacted}
        shl (16|M0)              r8.0<1>:d     r58.0<1;1,0>:d    16:w               {Compacted,$5.dst}
        mov (32|M0)              r30.0<1>:f    r56.0<1;1,0>:f                   {Compacted}
        shl (32|M0)              r25.0<1>:ud   r25.0<1;1,0>:ud   0x1:uw              {Compacted}
        shl (32|M0)              r27.0<1>:ud   r27.0<1;1,0>:ud   0x1:uw              {Compacted,I@7}
        bfn.0xA8 (32|M0)         r23.0<1>:ud   r1.3<0;0>:ud      r23.0<1;0>:ud     r12.0<1>:ud      {I@7} // s0&(s1|s2)
(W)     mov (1|M0)               r6.0<1>:f     0x70707070:f
        or (16|M0)               r31.0<1>:d    r10.0<1;1,0>:d    r7.0<1;1,0>:d    {Compacted,A@2}
        or (16|M0)               r12.0<1>:d    r8.0<1;1,0>:d     r11.0<1;1,0>:d   {Compacted,I@5}
        shr (16|M0)              r13.0<1>:ud   r58.0<1;1,0>:ud   0x8:uw
        bfn.0xEA (32|M0)         r14.0<1>:ud   r19.0<1;0>:ud     r25.0<1;0>:ud     r6.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r16.0<1>:ud   r23.0<1;0>:ud     r27.0<1;0>:ud     r6.0<0>:ud       {I@5} // s0|s1&s2
        and (32|M0)              r9.0<1>:w     r30.0<2;1,0>:w    4095:w               {I@5}
        and (32|M0)              r18.0<1>:w    r12.0<2;1,0>:w    4095:w               {I@4}
        shl (32|M0)              r30.0<1>:d    r30.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0x4:uw              {Compacted}
        sync.nop                             null                             {Compacted,I@5}
        sync.nop                             null                             {Compacted,$8.dst}
        dpas.8x8 (16|M0)         r70:d         r70:d             r14:u4            r65.0:b          {$6}
        mov (32|M0)              r21.0<1>:d    r18.0<1;1,0>:uw                  {I@3}
        mov (32|M0)              r15.0<1>:d    r9.0<1;1,0>:uw                   {$6.src}
        bfn.0xEA (32|M0)         r23.0<1>:ud   r21.0<1;0>:ud     r12.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
        bfn.0xEA (32|M0)         r19.0<1>:ud   r15.0<1;0>:ud     r30.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
        and (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0xFFF0000:ud
        and (32|M0)              r30.0<1>:ud   r30.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        bfn.0xA8 (32|M0)         r12.0<1>:ud   r1.2<0;0>:ud      r12.0<1;0>:ud     r21.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r30.0<1>:ud   r1.2<0;0>:ud      r30.0<1;0>:ud     r15.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r25.0<1>:ud   r12.0<1;0>:ud     r23.0<1;0>:ud     r5.0<0>:ud       {I@2} // s0|s1&s2
        bfn.0xEA (32|M0)         r7.0<1>:ud    r30.0<1;0>:ud     r19.0<1;0>:ud     r5.0<0>:ud       {I@2} // s0|s1&s2
        and (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x3F003F00:ud
        add (1|M0)               r37.1<1>:d    r37.1<0;1,0>:d    4:w
        shl (32|M0)              r25.0<1>:ud   r25.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
        shl (32|M0)              r7.0<1>:ud    r7.0<1;1,0>:ud    0x1:uw              {Compacted,I@5}
        bfn.0xA8 (32|M0)         r23.0<1>:ud   r1.3<0;0>:ud      r23.0<1;0>:ud     r12.0<1>:ud      {I@5} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r19.0<1>:ud   r1.3<0;0>:ud      r19.0<1;0>:ud     r30.0<1>:ud      {I@5} // s0&(s1|s2)
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r37.1<0;1,0>:ud   r4.10<0;1,0>:ud  {I@5}
        bfn.0xEA (32|M0)         r34.0<1>:ud   r23.0<1;0>:ud     r25.0<1;0>:ud     r6.0<0>:ud       {I@3} // s0|s1&s2
        bfn.0xEA (32|M0)         r32.0<1>:ud   r19.0<1;0>:ud     r7.0<1;0>:ud      r6.0<0>:ud       {I@3} // s0|s1&s2
        sync.nop                             null                             {I@1}
        dpas.8x8 (16|M0)         r78:d         r78:d             r32:u4            r59.0:b          {$7}
        add (1|M0)               r37.3<1>:uq   r38.0<0;1,0>:uq   0xC0:uw
        add (1|M0)               r37.4<1>:uq   r38.0<0;1,0>:uq   384:w
(W&f3.1) jmpi                                L2920
        mov (1|M0)               r38.0<1>:uq   r37.4<0;1,0>:uq                  {Compacted,@2,$15.src}
(W)     jmpi                                 L3056
        send.ugm (1|M0)          r65      r63  null:0  0x0            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r63.0<1>:q    r63.0<0;1,0>:q    r37.2<0;1,0>:q   {Compacted,$8.src}
        send.ugm (1|M0)          r45      r38  null:0  0x180000            0x0220E580           {I@3,$14} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0x180]
        send.ugm (1|M0)          r55      r38  null:0  0x200000            0x0210D580           {$10} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x200]
        send.ugm (1|M0)          r56      r38  null:0  0x240000            0x0220E580           {$12} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0x240]
        send.ugm (1|M0)          r58      r38  null:0  0x2C0000            0x0210D580           {$11} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x2C0]
        sync.nop                             null                             {Compacted,$7.src}
        send.ugm (1|M0)          r59      r63  null:0  0x0            0x0240F580           {I@1,$15} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        add (1|M0)               r38.0<1>:uq   r37.3<0;1,0>:uq   0x240:uw              {$11.src}
        add (1|M0)               r63.0<1>:q    r63.0<0;1,0>:q    r37.2<0;1,0>:q   {Compacted,$15.src}
        shr (16|M0)              r3.0<1>:ud    r39.0<1;1,0>:ud   0x18:uw              {Compacted,$9.dst}
        shl (16|M0)              r6.0<1>:d     r40.0<1;1,0>:d    8:w               {Compacted}
        shr (16|M0)              r7.0<1>:ud    r40.0<1;1,0>:ud   0x10:uw              {Compacted}
        shl (16|M0)              r8.0<1>:d     r41.0<1;1,0>:d    16:w               {Compacted,$1.dst}
        shr (16|M0)              r11.0<1>:ud   r41.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r40.0<1>:d    r6.0<1;1,0>:d     r3.0<1;1,0>:d    {Compacted,I@4}
        or (16|M0)               r10.0<1>:d    r8.0<1;1,0>:d     r7.0<1;1,0>:d    {I@3}
        and (32|M0)              r9.0<1>:w     r39.0<2;1,0>:w    4095:w               {I@2}
        and (32|M0)              r12.0<1>:w    r10.0<2;1,0>:w    4095:w               {I@2}
        shl (32|M0)              r39.0<1>:d    r39.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0x4:uw              {Compacted}
(W)     mov (1|M0)               r5.0<1>:f     0xFFF0000:f
        mov (32|M0)              r14.0<1>:d    r9.0<1;1,0>:uw                   {I@4}
        mov (32|M0)              r18.0<1>:d    r12.0<1;1,0>:uw                  {I@4}
        bfn.0xEA (32|M0)         r16.0<1>:ud   r14.0<1;0>:ud     r39.0<1;0>:ud     r5.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r20.0<1>:ud   r18.0<1;0>:ud     r10.0<1;0>:ud     r5.0<0>:ud       {I@2} // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
        and (32|M0)              r39.0<1>:ud   r39.0<1;1,0>:ud   0xFFF0000:ud
        and (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r16.0<1>:ud   r16.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r20.0<1>:ud   r20.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
(W)     mov (1|M0)               r3.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r39.0<1>:ud   r1.2<0;0>:ud      r39.0<1;0>:ud     r14.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r10.0<1>:ud   r1.2<0;0>:ud      r10.0<1;0>:ud     r18.0<1>:ud      {I@4} // s0&(s1|s2)
        shl (16|M0)              r22.0<1>:d    r44.0<1;1,0>:d    16:w               {Compacted,$15.dst}
        shl (16|M0)              r9.0<1>:d     r43.0<1;1,0>:d    8:w               {Compacted,$0.dst}
        bfn.0xEA (32|M0)         r7.0<1>:ud    r39.0<1;0>:ud     r16.0<1;0>:ud     r3.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r23.0<1>:ud   r10.0<1;0>:ud     r20.0<1;0>:ud     r3.0<0>:ud       {I@4} // s0|s1&s2
        shr (16|M0)              r18.0<1>:ud   r42.0<1;1,0>:ud   0x18:uw              {Compacted}
        shr (16|M0)              r19.0<1>:ud   r43.0<1;1,0>:ud   0x10:uw              {Compacted}
(W)     mov (1|M0)               r1.3<1>:f     0x7070707:f
        and (32|M0)              r16.0<1>:ud   r16.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r20.0<1>:ud   r20.0<1;1,0>:ud   0x3F003F00:ud
        shr (16|M0)              r27.0<1>:ud   r44.0<1;1,0>:ud   0x8:uw              {Compacted}
        shl (32|M0)              r7.0<1>:ud    r7.0<1;1,0>:ud    0x1:uw              {Compacted,I@7}
        or (16|M0)               r43.0<1>:d    r9.0<1;1,0>:d     r18.0<1;1,0>:d   {Compacted,I@6}
        or (16|M0)               r26.0<1>:d    r22.0<1;1,0>:d    r19.0<1;1,0>:d   {Compacted,I@6}
(W)     mov (1|M0)               r6.0<1>:f     0x70707070:f
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x1:uw
        bfn.0xA8 (32|M0)         r16.0<1>:ud   r1.3<0;0>:ud      r16.0<1;0>:ud     r39.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r20.0<1>:ud   r1.3<0;0>:ud      r20.0<1;0>:ud     r10.0<1>:ud      {I@7} // s0&(s1|s2)
        and (32|M0)              r10.0<1>:w    r42.0<2;1,0>:w    4095:w               {I@5}
        and (32|M0)              r11.0<1>:w    r26.0<2;1,0>:w    4095:w               {I@5}
        bfn.0xEA (32|M0)         r12.0<1>:ud   r16.0<1;0>:ud     r7.0<1;0>:ud      r6.0<0>:ud       {A@1} // s0|s1&s2
        shl (32|M0)              r42.0<1>:d    r42.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r26.0<1>:ud   r26.0<1;1,0>:ud   0x4:uw              {Compacted}
        bfn.0xEA (32|M0)         r14.0<1>:ud   r20.0<1;0>:ud     r23.0<1;0>:ud     r6.0<0>:ud       {I@6} // s0|s1&s2
        mov (32|M0)              r16.0<1>:d    r10.0<1;1,0>:uw                  {I@6}
        mov (32|M0)              r7.0<1>:d     r11.0<1;1,0>:uw                  {I@6}
        sync.nop                             null                             {Compacted,I@3}
        sync.nop                             null                             {Compacted,$6.dst}
        dpas.8x8 (16|M0)         r70:d         r70:d             r12:u4            r47.0:b          {$13}
        bfn.0xEA (32|M0)         r23.0<1>:ud   r7.0<1;0>:ud      r26.0<1;0>:ud     r5.0<0>:ud       {I@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r12.0<1>:ud   r16.0<1;0>:ud     r42.0<1;0>:ud     r5.0<0>:ud       {$13.src} // s0|s1&s2
        and (32|M0)              r26.0<1>:ud   r26.0<1;1,0>:ud   0xFFF0000:ud
        and (32|M0)              r42.0<1>:ud   r42.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        bfn.0xA8 (32|M0)         r26.0<1>:ud   r1.2<0;0>:ud      r26.0<1;0>:ud     r7.0<1>:ud       {I@4} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r42.0<1>:ud   r1.2<0;0>:ud      r42.0<1;0>:ud     r16.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r21.0<1>:ud   r26.0<1;0>:ud     r23.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
        bfn.0xEA (32|M0)         r19.0<1>:ud   r42.0<1;0>:ud     r12.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
        and (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0x3F003F00:ud
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
        shl (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
        bfn.0xA8 (32|M0)         r23.0<1>:ud   r1.3<0;0>:ud      r23.0<1;0>:ud     r26.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r12.0<1>:ud   r1.3<0;0>:ud      r12.0<1;0>:ud     r42.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r30.0<1>:ud   r23.0<1;0>:ud     r21.0<1;0>:ud     r6.0<0>:ud       {I@2} // s0|s1&s2
        bfn.0xEA (32|M0)         r28.0<1>:ud   r12.0<1;0>:ud     r19.0<1;0>:ud     r6.0<0>:ud       {I@2} // s0|s1&s2
        sync.nop                             null                             {I@1}
        sync.allwr                           ($7,$11)
        dpas.8x8 (16|M0)         r78:d         r78:d             r28:u4            r51.0:b          {$0}
(W&f3.1) jmpi                                L1696
