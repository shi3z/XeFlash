        send.ugm (1|M0)          r126     r4  null:0  0x0            0x0220E580           {I@1,$13} // wr:1+0, rd:2; load.ugm.d32x32t.a64
        send.ugm (1|M0)          r78      r4  null:0  0x80000            0x0210D580           {$12} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x80]
        send.ugm (1|M0)          r99      r64  null:0  0x0            0x0240F580           {$4} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r95      r64  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r89      r77  null:0  0x0            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r85      r77  null:0  0x100000            0x0240F580           {$14} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        sync.nop                             null                             {Compacted,$6.dst}
        shr (16|M0)              r3.0<1>:ud    r124.0<1;1,0>:ud  0x18:uw              {Compacted,$14.dst}
        shl (16|M0)              r6.0<1>:d     r125.0<1;1,0>:d   8:w               {Compacted}
        shr (16|M0)              r7.0<1>:ud    r125.0<1;1,0>:ud  0x10:uw              {Compacted}
        sync.nop                             null                             {Compacted,$7.dst}
        shl (16|M0)              r10.0<1>:d    r31.0<1;1,0>:d    16:w               {Compacted,$15.dst}
        mov (32|M0)              r8.0<1>:f     r124.0<1;1,0>:f                  {Compacted}
        shr (16|M0)              r13.0<1>:ud   r31.0<1;1,0>:ud   0x8:uw              {Compacted,$10.src}
        or (16|M0)               r12.0<1>:d    r10.0<1;1,0>:d    r7.0<1;1,0>:d    {Compacted,I@2}
        or (16|M0)               r9.0<1>:d     r6.0<1;1,0>:d     r3.0<1;1,0>:d    {Compacted,F@1}
        and (32|M0)              r14.0<1>:w    r12.0<2;1,0>:w    4095:w               {I@2}
        and (32|M0)              r11.0<1>:w    r8.0<2;1,0>:w     4095:w               {I@2}
        shl (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0x4:uw              {Compacted}
        shl (32|M0)              r8.0<1>:d     r8.0<1;1,0>:d     4:w               {Compacted}
(W)     mov (1|M0)               r17.0<1>:f    0xFFF0000:f
        mov (32|M0)              r21.0<1>:d    r14.0<1;1,0>:uw                  {I@4}
        mov (32|M0)              r15.0<1>:d    r11.0<1;1,0>:uw                  {I@4}
        bfn.0xEA (32|M0)         r23.0<1>:ud   r21.0<1;0>:ud     r12.0<1;0>:ud     r17.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r19.0<1>:ud   r15.0<1;0>:ud     r8.0<1;0>:ud      r17.0<0>:ud      {I@2} // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f
        and (32|M0)              r12.0<1>:ud   r12.0<1;1,0>:ud   0xFFF0000:ud
        and (32|M0)              r8.0<1>:ud    r8.0<1;1,0>:ud    0xFFF0000:ud
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
(W)     mov (1|M0)               r3.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r12.0<1>:ud   r1.2<0;0>:ud      r12.0<1;0>:ud     r21.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r8.0<1>:ud    r1.2<0;0>:ud      r8.0<1;0>:ud      r15.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r27.0<1>:ud   r12.0<1;0>:ud     r23.0<1;0>:ud     r3.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r25.0<1>:ud   r8.0<1;0>:ud      r19.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
(W)     mov (1|M0)               r2.3<1>:f     0x7070707:f                               {$8.src}
        and (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r19.0<1>:ud   r19.0<1;1,0>:ud   0x3F003F00:ud
        add (1|M0)               r4.6<1>:d     r4.6<0;1,0>:d     2:w               {$12.src}
        shl (32|M0)              r27.0<1>:ud   r27.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
        shl (32|M0)              r25.0<1>:ud   r25.0<1;1,0>:ud   0x1:uw              {Compacted,I@5}
(W)     mov (1|M0)               r6.0<1>:f     0x70707070:f
        bfn.0xA8 (32|M0)         r23.0<1>:ud   r2.3<0;0>:ud      r23.0<1;0>:ud     r12.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r19.0<1>:ud   r2.3<0;0>:ud      r19.0<1;0>:ud     r8.0<1>:ud       {I@5} // s0&(s1|s2)
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r4.6<0;1,0>:ud    r4.10<0;1,0>:ud  {I@5}
        bfn.0xEA (32|M0)         r16.0<1>:ud   r23.0<1;0>:ud     r27.0<1;0>:ud     r6.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r14.0<1>:ud   r19.0<1;0>:ud     r25.0<1;0>:ud     r6.0<0>:ud       {I@3} // s0|s1&s2
        sync.nop                             null                             {I@1}
        sync.allwr                           ($1,$2,$3,$5,$8,$10)
        dpas.8x8 (16|M0)         r48:d         r48:d             r14:u4            r69.0:b          {Atomic,$0.dst}
        dpas.8x8 (16|M0)         r56:d         r56:d             r14:u4            r65.0:b          {Atomic}
        dpas.8x8 (16|M0)         r32:d         r32:d             r14:u4            r81.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r40:d         r40:d             r14:u4            r73.0:ub         {$0}
        add (1|M0)               r2.0<1>:q     r64.0<0;1,0>:q    r4.2<0;1,0>:q    {Compacted}
        add (1|M0)               r1.0<1>:q     r77.0<0;1,0>:q    r4.2<0;1,0>:q    {Compacted}
        add (1|M0)               r1.1<1>:uq    r4.0<0;1,0>:uq    0xC0:uw
(W&f3.1) jmpi                                L3952
        mov (1|M0)               r64.0<1>:uq   r2.0<0;1,0>:uq                   {Compacted,@4,$11.src}
        mov (1|M0)               r77.0<1>:uq   r1.0<0;1,0>:uq                   {Compacted,@4,$14.src}
        mov (1|M0)               r4.0<1>:uq    r1.1<0;1,0>:uq                   {I@4}
(W)     jmpi                                 L4096
        send.ugm (1|M0)          r124     r4  null:0  0xC0000            0x0220E580           {I@2,$6} // wr:1+0, rd:2; load.ugm.d32x32t.a64.flat[A+0xC0]
        send.ugm (1|M0)          r31      r4  null:0  0x140000            0x0210D580           {$7} // wr:1+0, rd:1; load.ugm.d32x16t.a64.flat[A+0x140]
        sync.nop                             null                             {$0.src}
        send.ugm (1|M0)          r69      r2  null:0  0x0            0x0240F580           {$5} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r65      r2  null:0  0x100000            0x0240F580           {$8} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r81      r1  null:0  0x0            0x0240F580           {$9} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r73      r1  null:0  0x100000            0x0240F580           {$11} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        add (1|M0)               r64.0<1>:q    r64.0<0;1,0>:q    r4.1<0;1,0>:q    {Compacted,$11.src}
        add (1|M0)               r77.0<1>:q    r77.0<0;1,0>:q    r4.1<0;1,0>:q    {Compacted,$14.src}
        add (1|M0)               r4.0<1>:uq    r4.0<0;1,0>:uq    0x180:uw              {$7.src}
        shr (16|M0)              r3.0<1>:ud    r126.0<1;1,0>:ud  0x18:uw              {Compacted,$13.dst}
        shl (16|M0)              r6.0<1>:d     r127.0<1;1,0>:d   8:w               {Compacted}
        shr (16|M0)              r7.0<1>:ud    r127.0<1;1,0>:ud  0x10:uw              {Compacted}
        shl (16|M0)              r8.0<1>:d     r78.0<1;1,0>:d    16:w               {Compacted,$12.dst}
        shr (16|M0)              r11.0<1>:ud   r78.0<1;1,0>:ud   0x8:uw              {Compacted}
        or (16|M0)               r127.0<1>:d   r6.0<1;1,0>:d     r3.0<1;1,0>:d    {Compacted,I@4}
        or (16|M0)               r10.0<1>:d    r8.0<1;1,0>:d     r7.0<1;1,0>:d    {I@3}
        and (32|M0)              r9.0<1>:w     r126.0<2;1,0>:w   4095:w               {I@2}
        and (32|M0)              r12.0<1>:w    r10.0<2;1,0>:w    4095:w               {I@2}
        shl (32|M0)              r126.0<1>:d   r126.0<1;1,0>:d   4:w               {Compacted}
        shl (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0x4:uw              {Compacted}
(W)     mov (1|M0)               r13.0<1>:f    0xFFF0000:f
        mov (32|M0)              r14.0<1>:d    r9.0<1;1,0>:uw                   {@4,$0.src}
        mov (32|M0)              r19.0<1>:d    r12.0<1;1,0>:uw                  {I@4}
        bfn.0xEA (32|M0)         r16.0<1>:ud   r14.0<1;0>:ud     r126.0<1;0>:ud    r13.0<0>:ud      {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r21.0<1>:ud   r19.0<1;0>:ud     r10.0<1;0>:ud     r13.0<0>:ud      {I@2} // s0|s1&s2
(W)     mov (1|M0)               r1.2<1>:f     5.785725e-39:f                               {$11.src}
        and (32|M0)              r126.0<1>:ud  r126.0<1;1,0>:ud  0xFFF0000:ud
        and (32|M0)              r10.0<1>:ud   r10.0<1;1,0>:ud   0xFFF0000:ud
        shl (32|M0)              r16.0<1>:ud   r16.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
        shl (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x2:uw              {Compacted,I@4}
(W)     mov (1|M0)               r3.0<1>:f     5.009613e-01:f
        bfn.0xA8 (32|M0)         r126.0<1>:ud  r1.2<0;0>:ud      r126.0<1;0>:ud    r14.0<1>:ud      {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r10.0<1>:ud   r1.2<0;0>:ud      r10.0<1;0>:ud     r19.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r7.0<1>:ud    r126.0<1;0>:ud    r16.0<1;0>:ud     r3.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r23.0<1>:ud   r10.0<1;0>:ud     r21.0<1;0>:ud     r3.0<0>:ud       {I@2} // s0|s1&s2
(W)     mov (1|M0)               r9.0<1>:f     0x7070707:f
        and (32|M0)              r16.0<1>:ud   r16.0<1;1,0>:ud   0x3F003F00:ud
        and (32|M0)              r21.0<1>:ud   r21.0<1;1,0>:ud   0x3F003F00:ud
        shl (32|M0)              r7.0<1>:ud    r7.0<1;1,0>:ud    0x1:uw              {Compacted,I@4}
        shl (32|M0)              r23.0<1>:ud   r23.0<1;1,0>:ud   0x1:uw              {Compacted,I@4}
(W)     mov (1|M0)               r6.0<1>:f     0x70707070:f
        bfn.0xA8 (32|M0)         r16.0<1>:ud   r9.0<0;0>:ud      r16.0<1;0>:ud     r126.0<1>:ud     {A@2} // s0&(s1|s2)
        bfn.0xA8 (32|M0)         r21.0<1>:ud   r9.0<0;0>:ud      r21.0<1;0>:ud     r10.0<1>:ud      {I@4} // s0&(s1|s2)
        bfn.0xEA (32|M0)         r12.0<1>:ud   r16.0<1;0>:ud     r7.0<1;0>:ud      r6.0<0>:ud       {A@1} // s0|s1&s2
        bfn.0xEA (32|M0)         r14.0<1>:ud   r21.0<1;0>:ud     r23.0<1;0>:ud     r6.0<0>:ud       {I@2} // s0|s1&s2
        sync.nop                             null                             {I@1}
        sync.allwr                           ($0,$9,$11,$14)
        dpas.8x8 (16|M0)         r48:d         r48:d             r12:u4            r99.0:b          {Atomic,$4.dst}
        dpas.8x8 (16|M0)         r56:d         r56:d             r12:u4            r95.0:b          {Atomic}
        dpas.8x8 (16|M0)         r32:d         r32:d             r12:u4            r89.0:ub         {Atomic}
        dpas.8x8 (16|M0)         r40:d         r40:d             r12:u4            r85.0:ub         {$12}
(W&f3.1) jmpi                                L3136
