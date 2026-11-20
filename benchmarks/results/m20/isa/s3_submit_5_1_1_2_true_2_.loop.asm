        send.ugm (1|M0)          r48      r40  null:0  0x0            0x0220E580           {$15} // wr:1+0, rd:2; load.ugm.d32x32t.a64
        send.ugm (1|M0)          r42      r40  null:0  0x80000            0x0210D580           {$0} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x80]
        sync.nop                             null                             {$10.src}
        send.ugm (1|M0)          r51      r58  null:0  0x0            0x0210C580           {$14} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r53      r64  null:0  0x0            0x0210C580           {$1} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r54      r40  null:0  0xC0000            0x0220E580           {$2} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0xC0]
        send.ugm (1|M0)          r50      r40  null:0  0x140000            0x0210D580           {$3} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x140]
        shl (16|M0)              r7.0<1>:d     r61.0<1;1,0>:d    8:w               {Compacted,$4.dst}
        shr (16|M0)              r8.0<1>:ud    r60.0<1;1,0>:ud   0x18:uw              {Compacted}
        shl (16|M0)              r11.0<1>:d    r52.0<1;1,0>:d    16:w               {Compacted,$5.dst}
        shr (16|M0)              r12.0<1>:ud   r61.0<1;1,0>:ud   0x10:uw              {Compacted}
        mov (32|M0)              r9.0<1>:f     r60.0<1;1,0>:f                   {Compacted}
        add (1|M0)               r3.0<1>:q     r58.0<0;1,0>:q    r32.3<0;1,0>:q   {Compacted}
        shr (16|M0)              r14.0<1>:ud   r52.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r13.0<1>:d    r11.0<1;1,0>:d    r12.0<1;1,0>:d   {Compacted,I@3}
        or (16|M0)               r10.0<1>:d    r7.0<1;1,0>:d     r8.0<1;1,0>:d    {Compacted,F@1}
        sync.nop                             null                             {Compacted,$13.src}
        send.ugm (1|M0)          r57      r3  null:0  0x0            0x0210C580           {I@4,$10} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r58.0<1>:q    r3.0<0;1,0>:q     r32.3<0;1,0>:q   {Compacted,$14.src}
        and (32|M0)              r15.0<1>:w    r13.0<2;1,0>:w    4095:w               {I@3}
        and (32|M0)              r3.0<1>:w     r9.0<2;1,0>:w     4095:w               {@3,$10.src}
        shl (32|M0)              r13.0<1>:ud   r13.0<1;1,0>:ud   0x4:uw              {Compacted}
        shl (32|M0)              r9.0<1>:d     r9.0<1;1,0>:d     4:w               {Compacted}
        add (1|M0)               r6.0<1>:q     r64.0<0;1,0>:q    r32.3<0;1,0>:q   {Compacted}
(W)     mov (1|M0)               r8.0<1>:f     0xFFF0000:f
        mov (32|M0)              r19.0<1>:d    r15.0<1;1,0>:uw                  {I@5}
        mov (32|M0)              r17.0<1>:d    r3.0<1;1,0>:uw                   {I@5}
        send.ugm (1|M0)          r59      r6  null:0  0x0            0x0210C580           {I@3,$12} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        and (32|M0)              r22.0<1>:d    r9.0<1;1,0>:d     268369920:d
        add (1|M0)               r64.0<1>:q    r6.0<0;1,0>:q     r32.3<0;1,0>:q   {$1.src}
        and (32|M0)              r6.0<1>:ud    r13.0<1;1,0>:ud   0xFFF0000:ud              {$12.src}
        bfn.0xEA (32|M0)         r9.0<1>:ud    r17.0<1;0>:ud     r9.0<1;0>:ud      r8.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r13.0<1>:ud   r19.0<1;0>:ud     r13.0<1;0>:ud     r8.0<0>:ud       // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x2:uw              {Compacted,I@2}
        shl (32|M0)              r13.0<1>:ud   r13.0<1;1,0>:ud   0x2:uw              {Compacted,I@2}
(W)     mov (1|M0)               r3.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r22.0<1>:ud   r1.2<0;0>:ud      r22.0<1;0>:ud     r17.0<1>:ud      {F@2} // s0&(s1|s2)
(W)     mov (1|M0)               r1.3<1>:f     0x7070707:f
        bfn.0xA8 (32|M0)         r6.0<1>:ud    r1.2<0;0>:ud      r6.0<1;0>:ud      r19.0<1>:ud      // s0&(s1|s2)
        and (32|M0)              r11.0<1>:ud   r9.0<1;1,0>:ud    0x3F003F00:ud              {I@4}
        and (32|M0)              r15.0<1>:ud   r13.0<1;1,0>:ud   0x3F003F00:ud              {I@4}
        bfn.0xEA (32|M0)         r9.0<1>:ud    r22.0<1;0>:ud     r9.0<1;0>:ud      r3.0<0>:ud       {A@2} // s0|s1&s2
        bfn.0xEA (32|M0)         r13.0<1>:ud   r6.0<1;0>:ud      r13.0<1;0>:ud     r3.0<0>:ud       {I@4} // s0|s1&s2
        bfn.0xA8 (32|M0)         r15.0<1>:ud   r1.3<0;0>:ud      r15.0<1;0>:ud     r6.0<1>:ud       {A@1} // s0&(s1|s2)
        shl (16|M0)              r17.0<1>:d    r63.0<1;1,0>:d    8:w               {Compacted,$10.dst}
        shr (16|M0)              r19.0<1>:ud   r62.0<1;1,0>:ud   0x18:uw              {Compacted}
        shl (16|M0)              r20.0<1>:d    r56.0<1;1,0>:d    16:w               {Compacted,$11.dst}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x1:uw              {Compacted,I@6}
        shr (16|M0)              r6.0<1>:ud    r63.0<1;1,0>:ud   0x10:uw              {Compacted}
        mov (32|M0)              r29.0<1>:f    r62.0<1;1,0>:f                   {Compacted,$9.src}
(W)     mov (1|M0)               r18.0<1>:f    0x70707070:f
        bfn.0xA8 (32|M0)         r11.0<1>:ud   r1.3<0;0>:ud      r11.0<1;0>:ud     r22.0<1>:ud      // s0&(s1|s2)
        or (16|M0)               r21.0<1>:d    r20.0<1;1,0>:d    r6.0<1;1,0>:d    {Compacted,I@2}
        or (16|M0)               r30.0<1>:d    r17.0<1;1,0>:d    r19.0<1;1,0>:d   {Compacted,F@2}
        shr (16|M0)              r22.0<1>:ud   r56.0<1;1,0>:ud   0x8:uw              {Compacted}
        shl (32|M0)              r13.0<1>:ud   r13.0<1;1,0>:ud   0x1:uw              {Compacted}
        bfn.0xEA (32|M0)         r24.0<1>:ud   r11.0<1;0>:ud     r9.0<1;0>:ud      r18.0<0>:ud      {A@1} // s0|s1&s2
        and (32|M0)              r7.0<1>:w     r29.0<2;1,0>:w    4095:w               {I@4}
        and (32|M0)              r9.0<1>:w     r21.0<2;1,0>:w    4095:w               {I@4}
        shl (32|M0)              r29.0<1>:d    r29.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x4:uw              {Compacted}
        bfn.0xEA (32|M0)         r26.0<1>:ud   r15.0<1;0>:ud     r13.0<1;0>:ud     r18.0<0>:ud      {I@6} // s0|s1&s2
        mov (32|M0)              r11.0<1>:d    r7.0<1;1,0>:uw                   {I@5}
        mov (32|M0)              r13.0<1>:d    r9.0<1;1,0>:uw                   {I@5}
        sync.nop                             null                             {I@3}
        dpas.8x1 (16|M0)         r74:d         r74:d             r24:u4            r67.0:b          {$6}
        dpas.8x1 (16|M0)         r66:d         r66:d             r24:u4            r71.0:ub         {$7}
        and (32|M0)              r16.0<1>:ud   r21.0<1;1,0>:ud   0xFFF0000:ud
        and (32|M0)              r24.0<1>:d    r29.0<1;1,0>:d    268369920:d               {$7.src}
        bfn.0xEA (32|M0)         r21.0<1>:ud   r13.0<1;0>:ud     r21.0<1;0>:ud     r8.0<0>:ud       {I@3} // s0|s1&s2
        bfn.0xEA (32|M0)         r29.0<1>:ud   r11.0<1;0>:ud     r29.0<1;0>:ud     r8.0<0>:ud       // s0|s1&s2
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x2:uw              {Compacted,I@2}
        shl (32|M0)              r29.0<1>:ud   r29.0<1;1,0>:ud   0x2:uw              {Compacted,I@2}
        bfn.0xA8 (32|M0)         r16.0<1>:ud   r1.2<0;0>:ud      r16.0<1;0>:ud     r13.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r24.0<1>:ud   r1.2<0;0>:ud      r24.0<1;0>:ud     r11.0<1>:ud      // s0&(s1|s2)
        and (32|M0)              r27.0<1>:ud   r21.0<1;1,0>:ud   0x3F003F00:ud              {I@4}
        and (32|M0)              r19.0<1>:ud   r29.0<1;1,0>:ud   0x3F003F00:ud              {I@4}
        bfn.0xEA (32|M0)         r21.0<1>:ud   r16.0<1;0>:ud     r21.0<1;0>:ud     r3.0<0>:ud       {I@4} // s0|s1&s2
        bfn.0xEA (32|M0)         r29.0<1>:ud   r24.0<1;0>:ud     r29.0<1;0>:ud     r3.0<0>:ud       {I@4} // s0|s1&s2
        add (1|M0)               r32.1<1>:d    r32.1<0;1,0>:d    4:w
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x1:uw              {Compacted,I@3}
        shl (32|M0)              r29.0<1>:ud   r29.0<1;1,0>:ud   0x1:uw              {Compacted,I@3}
        bfn.0xA8 (32|M0)         r27.0<1>:ud   r1.3<0;0>:ud      r27.0<1;0>:ud     r16.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r19.0<1>:ud   r1.3<0;0>:ud      r19.0<1;0>:ud     r24.0<1>:ud      // s0&(s1|s2)
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r32.1<0;1,0>:ud   r4.10<0;1,0>:ud  {I@5}
        bfn.0xEA (32|M0)         r8.0<1>:ud    r27.0<1;0>:ud     r21.0<1;0>:ud     r18.0<0>:ud      {I@3} // s0|s1&s2
        bfn.0xEA (32|M0)         r6.0<1>:ud    r19.0<1;0>:ud     r29.0<1;0>:ud     r18.0<0>:ud      {I@3} // s0|s1&s2
        sync.nop                             null                             {Compacted,I@1}
        sync.nop                             null                             {Compacted,$13.dst}
        dpas.8x1 (16|M0)         r72:d         r72:d             r6:u4             r65.0:b          {$8}
        dpas.8x1 (16|M0)         r68:d         r68:d             r6:u4             r69.0:ub         {$9}
        add (1|M0)               r32.4<1>:uq   r40.0<0;1,0>:uq   0xC0:uw
        add (1|M0)               r32.5<1>:uq   r40.0<0;1,0>:uq   384:w
(W&f3.1) jmpi                                L5368
        mov (1|M0)               r40.0<1>:uq   r32.5<0;1,0>:uq                  {Compacted,@2,$3.src}
(W)     jmpi                                 L5576
        sync.nop                             null                             {Compacted,$6.src}
        send.ugm (1|M0)          r67      r58  null:0  0x0            0x0210C580           {$1} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        send.ugm (1|M0)          r71      r64  null:0  0x0            0x0210C580           {$11} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r58.0<1>:q    r58.0<0;1,0>:q    r32.3<0;1,0>:q   {Compacted,$1.src}
        add (1|M0)               r64.0<1>:q    r64.0<0;1,0>:q    r32.3<0;1,0>:q   {Compacted,$11.src}
        send.ugm (1|M0)          r60      r40  null:0  0x180000            0x0220E580           {I@4,$14} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0x180]
        send.ugm (1|M0)          r52      r40  null:0  0x200000            0x0210D580           {$2} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x200]
        send.ugm (1|M0)          r62      r40  null:0  0x240000            0x0220E580           {$3} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0x240]
        send.ugm (1|M0)          r56      r40  null:0  0x2C0000            0x0210D580           {$0} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x2C0]
        sync.nop                             null                             {$8.src}
        send.ugm (1|M0)          r65      r58  null:0  0x0            0x0210C580           {I@2,$4} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        sync.nop                             null                             {Compacted,$9.src}
        send.ugm (1|M0)          r69      r64  null:0  0x0            0x0210C580           {I@1,$5} // wr:1+0, rd:1; load.ugm.d32x8t.a64
        add (1|M0)               r40.0<1>:uq   r32.4<0;1,0>:uq   0x240:uw              {$0.src}
        add (1|M0)               r58.0<1>:q    r58.0<0;1,0>:q    r32.3<0;1,0>:q   {Compacted,$4.src}
        add (1|M0)               r64.0<1>:q    r64.0<0;1,0>:q    r32.3<0;1,0>:q   {Compacted,$5.src}
        shl (16|M0)              r3.0<1>:d     r49.0<1;1,0>:d    8:w               {Compacted,$15.dst}
        shr (16|M0)              r6.0<1>:ud    r48.0<1;1,0>:ud   0x18:uw              {Compacted,$9.src}
        shr (16|M0)              r7.0<1>:ud    r49.0<1;1,0>:ud   0x10:uw              {Compacted}
        shl (16|M0)              r8.0<1>:d     r42.0<1;1,0>:d    16:w               {Compacted,$0.dst}
        shr (16|M0)              r10.0<1>:ud   r42.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r49.0<1>:d    r3.0<1;1,0>:d     r6.0<1;1,0>:d    {Compacted,I@4}
        or (16|M0)               r9.0<1>:d     r8.0<1;1,0>:d     r7.0<1;1,0>:d    {Compacted,I@3}
        and (32|M0)              r11.0<1>:w    r48.0<2;1,0>:w    4095:w               {I@2}
        and (32|M0)              r12.0<1>:w    r9.0<2;1,0>:w     4095:w               {I@2}
        shl (32|M0)              r48.0<1>:d    r48.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x4:uw              {Compacted}
(W)     mov (1|M0)               r6.0<1>:f     0xFFF0000:f
        mov (32|M0)              r13.0<1>:d    r11.0<1;1,0>:uw                  {I@4}
        mov (32|M0)              r15.0<1>:d    r12.0<1;1,0>:uw                  {I@4}
        and (32|M0)              r18.0<1>:d    r48.0<1;1,0>:d    268369920:d               {I@4}
        and (32|M0)              r20.0<1>:ud   r9.0<1;1,0>:ud    0xFFF0000:ud              {I@4}
        bfn.0xEA (32|M0)         r48.0<1>:ud   r13.0<1;0>:ud     r48.0<1;0>:ud     r6.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r9.0<1>:ud    r15.0<1;0>:ud     r9.0<1;0>:ud      r6.0<0>:ud       {I@4} // s0|s1&s2
        shl (32|M0)              r48.0<1>:ud   r48.0<1;1,0>:ud   0x2:uw              {Compacted,I@2}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x2:uw              {Compacted,I@2}
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
(W)     mov (1|M0)               r1.3<1>:f     0x7070707:f
(W)     mov (1|M0)               r3.0<1>:f     5.009613e-01:f
        and (32|M0)              r7.0<1>:ud    r48.0<1;1,0>:ud   0x3F003F00:ud              {I@2}
        and (32|M0)              r11.0<1>:ud   r9.0<1;1,0>:ud    0x3F003F00:ud              {I@2}
        bfn.0xA8 (32|M0)         r18.0<1>:ud   r1.2<0;0>:ud      r18.0<1;0>:ud     r13.0<1>:ud      {F@3} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r20.0<1>:ud   r1.2<0;0>:ud      r20.0<1;0>:ud     r15.0<1>:ud      // s0&(s1|s2)
        shl (16|M0)              r17.0<1>:d    r50.0<1;1,0>:d    16:w               {Compacted,$3.dst}
        shl (16|M0)              r13.0<1>:d    r55.0<1;1,0>:d    8:w               {Compacted,$2.dst}
        shr (16|M0)              r15.0<1>:ud   r54.0<1;1,0>:ud   0x18:uw              {Compacted}
        shr (16|M0)              r16.0<1>:ud   r55.0<1;1,0>:ud   0x10:uw              {Compacted}
        bfn.0xEA (32|M0)         r48.0<1>:ud   r18.0<1;0>:ud     r48.0<1;0>:ud     r3.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xA8 (32|M0)         r7.0<1>:ud    r1.3<0;0>:ud      r7.0<1;0>:ud      r18.0<1>:ud      // s0&(s1|s2)
        bfn.0xEA (32|M0)         r9.0<1>:ud    r20.0<1;0>:ud     r9.0<1;0>:ud      r3.0<0>:ud       {I@7} // s0|s1&s2
        bfn.0xA8 (32|M0)         r11.0<1>:ud   r1.3<0;0>:ud      r11.0<1;0>:ud     r20.0<1>:ud      // s0&(s1|s2)
        or (16|M0)               r55.0<1>:d    r13.0<1;1,0>:d    r15.0<1;1,0>:d   {Compacted,I@6}
        or (16|M0)               r19.0<1>:d    r17.0<1;1,0>:d    r16.0<1;1,0>:d   {Compacted,I@6}
        shr (16|M0)              r20.0<1>:ud   r50.0<1;1,0>:ud   0x8:uw              {Compacted}
        shl (32|M0)              r48.0<1>:ud   r48.0<1;1,0>:ud   0x1:uw              {Compacted,I@7}
        shl (32|M0)              r9.0<1>:ud    r9.0<1;1,0>:ud    0x1:uw              {I@6}
(W)     mov (1|M0)               r14.0<1>:f    0x70707070:f
        and (32|M0)              r18.0<1>:w    r54.0<2;1,0>:w    4095:w               {I@5}
        and (32|M0)              r21.0<1>:w    r19.0<2;1,0>:w    4095:w               {I@4}
        shl (32|M0)              r54.0<1>:d    r54.0<1;1,0>:d    4:w               {Compacted}
        shl (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x4:uw              {Compacted}
        bfn.0xEA (32|M0)         r22.0<1>:ud   r7.0<1;0>:ud      r48.0<1;0>:ud     r14.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r24.0<1>:ud   r11.0<1;0>:ud     r9.0<1;0>:ud      r14.0<0>:ud      {I@6} // s0|s1&s2
        mov (32|M0)              r7.0<1>:d     r18.0<1;1,0>:uw                  {I@6}
        mov (32|M0)              r9.0<1>:d     r21.0<1;1,0>:uw                  {I@6}
        sync.nop                             null                             {I@3}
        sync.allwr                           ($6,$14)
        dpas.8x1 (16|M0)         r74:d         r74:d             r22:u4            r51.0:b          {$10}
        sync.allwr                           ($1,$7)
        dpas.8x1 (16|M0)         r66:d         r66:d             r22:u4            r53.0:ub         {$12}
        and (32|M0)              r22.0<1>:d    r54.0<1;1,0>:d    268369920:d               {$12.src}
        and (32|M0)              r24.0<1>:ud   r19.0<1;1,0>:ud   0xFFF0000:ud
        bfn.0xEA (32|M0)         r54.0<1>:ud   r7.0<1;0>:ud      r54.0<1;0>:ud     r6.0<0>:ud       {I@4} // s0|s1&s2
        bfn.0xEA (32|M0)         r19.0<1>:ud   r9.0<1;0>:ud      r19.0<1;0>:ud     r6.0<0>:ud       {I@4} // s0|s1&s2
        shl (32|M0)              r54.0<1>:ud   r54.0<1;1,0>:ud   0x2:uw              {Compacted,I@2}
        shl (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x2:uw              {Compacted,I@2}
        bfn.0xA8 (32|M0)         r22.0<1>:ud   r1.2<0;0>:ud      r22.0<1;0>:ud     r7.0<1>:ud       // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r24.0<1>:ud   r1.2<0;0>:ud      r24.0<1;0>:ud     r9.0<1>:ud       // s0&(s1|s2)
        and (32|M0)              r11.0<1>:ud   r54.0<1;1,0>:ud   0x3F003F00:ud              {I@4}
        and (32|M0)              r15.0<1>:ud   r19.0<1;1,0>:ud   0x3F003F00:ud              {I@4}
        bfn.0xEA (32|M0)         r54.0<1>:ud   r22.0<1;0>:ud     r54.0<1;0>:ud     r3.0<0>:ud       {I@4} // s0|s1&s2
        bfn.0xEA (32|M0)         r19.0<1>:ud   r24.0<1;0>:ud     r19.0<1;0>:ud     r3.0<0>:ud       {I@4} // s0|s1&s2
        shl (32|M0)              r54.0<1>:ud   r54.0<1;1,0>:ud   0x1:uw              {Compacted,I@2}
        shl (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x1:uw              {Compacted,I@2}
        bfn.0xA8 (32|M0)         r11.0<1>:ud   r1.3<0;0>:ud      r11.0<1;0>:ud     r22.0<1>:ud      // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r15.0<1>:ud   r1.3<0;0>:ud      r15.0<1;0>:ud     r24.0<1>:ud      // s0&(s1|s2)
        bfn.0xEA (32|M0)         r26.0<1>:ud   r11.0<1;0>:ud     r54.0<1;0>:ud     r14.0<0>:ud      {I@2} // s0|s1&s2
        bfn.0xEA (32|M0)         r28.0<1>:ud   r15.0<1;0>:ud     r19.0<1;0>:ud     r14.0<0>:ud      {I@2} // s0|s1&s2
        sync.nop                             null                             {Compacted,I@1}
        sync.allwr                           ($8,$10)
        dpas.8x1 (16|M0)         r72:d         r72:d             r26:u4            r57.0:b          {$13}
        sync.allwr                           ($9,$12)
        dpas.8x1 (16|M0)         r68:d         r68:d             r26:u4            r59.0:ub         {Compacted,$15}
(W&f3.1) jmpi                                L4096
